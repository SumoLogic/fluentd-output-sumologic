require 'fluent/plugin/output'
require 'net/https'
require 'yajl'
require 'httpclient'

class SumologicConnection

  attr_reader :http

  def initialize(endpoint, verify_ssl, connect_timeout)
    @endpoint = endpoint
    create_http_client(verify_ssl, connect_timeout)
  end

  def publish(raw_data, source_host=nil, source_category=nil, source_name=nil)
    response = http.post(@endpoint, raw_data, request_headers(source_host, source_category, source_name))
    unless response.ok?
      raise "Failed to send data to HTTP Source. #{response.code} - #{response.body}"
    end
  end

  private

  def request_headers(source_host, source_category, source_name)
    {
        'X-Sumo-Name'     => source_name,
        'X-Sumo-Category' => source_category,
        'X-Sumo-Host'     => source_host
    }
  end

  def ssl_options(verify_ssl)
    verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
  end

  def create_http_client(verify_ssl, connect_timeout)
    @http                        = HTTPClient.new
    @http.ssl_config.verify_mode = ssl_options(verify_ssl)
    @http.connect_timeout        = connect_timeout
  end
end

class Fluent::Plugin::Sumologic < Fluent::Plugin::Output
  # First, register the plugin. NAME is the name of this plugin
  # and identifies the plugin in the configuration file.
  Fluent::Plugin.register_output('sumologic', self)

  helpers :compat_parameters
  DEFAULT_BUFFER_TYPE = "memory"

  config_param :endpoint, :string
  config_param :log_format, :string, :default => 'json'
  config_param :log_key, :string, :default => 'message'
  config_param :source_category, :string, :default => nil
  config_param :source_name, :string, :default => nil
  config_param :source_name_key, :string, :default => 'source_name'
  config_param :source_host, :string, :default => nil
  config_param :verify_ssl, :bool, :default => true
  config_param :delimiter, :string, :default => "."
  config_param :open_timeout, :integer, :default => 60

  config_section :buffer do
    config_set_default :@type, DEFAULT_BUFFER_TYPE
    config_set_default :chunk_keys, ['tag']
  end

  def initialize
    super
  end

  # This method is called before starting.
  def configure(conf)

    compat_parameters_convert(conf, :buffer)

    unless conf['endpoint'] =~ URI::regexp
      raise Fluent::ConfigError, "Invalid SumoLogic endpoint url: #{conf['endpoint']}"
    end

    unless conf['log_format'] =~ /\A(?:json|text|json_merge)\z/
      raise Fluent::ConfigError, "Invalid log_format #{conf['log_format']} must be text, json or json_merge"
    end

    @sumo_conn = SumologicConnection.new(conf['endpoint'], conf['verify_ssl'], conf['open_timeout'].to_i)
    super
  end

  # This method is called when starting.
  def start
    super
  end

  # This method is called when shutting down.
  def shutdown
    super
  end

  # Used to merge log record into top level json
  def merge_json(record)
    if record.has_key?(@log_key)
      log = record[@log_key].strip
      if log[0].eql?('{') && log[-1].eql?('}')
        begin
          record = JSON.parse(log).merge(record)
          record.delete(@log_key)
        rescue JSON::ParserError
          # do nothing, ignore
        end
      end
    end
    record
  end

  # Strip sumo_metadata and dump to json
  def dump_log(log)
    log.delete('_sumo_metadata')
    Yajl.dump(log)
  end

  def format(tag, time, record)
    if defined? time.nsec
      mstime = time * 1000 + (time.nsec / 1000000)
      [mstime, record].to_msgpack
    else
      [time, record].to_msgpack
    end
  end

  def formatted_to_msgpack_binary
    true
  end

  def sumo_key(sumo_metadata, record, tag)
    source_name = sumo_metadata['source'] || @source_name
    source_name = expand_param(source_name, tag, nil, record)

    source_category = sumo_metadata['category'] || @source_category
    source_category = expand_param(source_category, tag, nil, record)

    source_host = sumo_metadata['host'] || @source_host
    source_host = expand_param(source_host, tag, nil, record)

    "#{source_name}:#{source_category}:#{source_host}"
  end

  # Convert timestamp to 13 digit epoch if necessary
  def sumo_timestamp(time)
    time.to_s.length == 13 ? time : time * 1000
  end

  # copy from https://github.com/uken/fluent-plugin-elasticsearch/commit/1722c58758b4da82f596ecb0a5075d3cb6c99b2e#diff-33bfa932bf1443760673c69df745272eR221
  def expand_param(param, tag, time, record)
    # check for '${ ... }'
    #   yes => `eval`
    #   no  => return param
    return param if (param =~ /\${.+}/).nil?

    # check for 'tag_parts[]'
      # separated by a delimiter (default '.')
    tag_parts = tag.split(@delimiter) unless (param =~ /tag_parts\[.+\]/).nil? || tag.nil?

    # pull out section between ${} then eval
    inner = param.clone
    while inner.match(/\${.+}/)
      to_eval = inner.match(/\${(.+?)}/){$1}

      if !(to_eval =~ /record\[.+\]/).nil? && record.nil?
        return to_eval
      elsif !(to_eval =~/tag_parts\[.+\]/).nil? && tag_parts.nil?
        return to_eval
      elsif !(to_eval =~/time/).nil? && time.nil?
        return to_eval
      else
        inner.sub!(/\${.+?}/, eval( to_eval ))
      end
    end
    inner
  end

  # This method is called every flush interval. Write the buffer chunk
  def write(chunk)
    messages_list = {}

    # Sort messages
    chunk.msgpack_each do |time, record|
      # plugin dies randomly
      # https://github.com/uken/fluent-plugin-elasticsearch/commit/8597b5d1faf34dd1f1523bfec45852d380b26601#diff-ae62a005780cc730c558e3e4f47cc544R94
      next unless record.is_a? Hash
      sumo_metadata = record.fetch('_sumo_metadata', {'source' => record[@source_name_key]})
      key = sumo_key(sumo_metadata, record, tag)
      log_format = sumo_metadata['log_format'] || @log_format

      # Strip any unwanted newlines
      record[@log_key].chomp! if record[@log_key]

      case log_format
        when 'text'
          log = record[@log_key]
          unless log.nil?
            log.strip!
          end
        when 'json_merge'
          log = dump_log(merge_json({:timestamp => sumo_timestamp(time)}.merge(record)))
        else
          log = dump_log({:timestamp => sumo_timestamp(time)}.merge(record))
      end

      unless log.nil?
        if messages_list.key?(key)
          messages_list[key].push(log)
        else
          messages_list[key] = [log]
        end
      end

    end

    # Push logs to sumo
    messages_list.each do |key, messages|
      source_name, source_category, source_host = key.split(':')
      @sumo_conn.publish(
          messages.join("\n"),
          source_host=source_host,
          source_category=source_category,
          source_name=source_name
      )
    end

  end
end
