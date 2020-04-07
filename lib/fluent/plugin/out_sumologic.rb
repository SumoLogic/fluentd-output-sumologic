require 'fluent/plugin/output'
require 'net/https'
require 'yajl'
require 'httpclient'

class SumologicConnection

  attr_reader :http

  def initialize(endpoint, verify_ssl, connect_timeout, proxy_uri, disable_cookies)
    @endpoint = endpoint
    create_http_client(verify_ssl, connect_timeout, proxy_uri, disable_cookies)
  end

  def publish(raw_data, source_host=nil, source_category=nil, source_name=nil, data_type, metric_data_type, collected_fields)
    response = http.post(@endpoint, raw_data, request_headers(source_host, source_category, source_name, data_type, metric_data_type, collected_fields))
    unless response.ok?
      raise RuntimeError, "Failed to send data to HTTP Source. #{response.code} - #{response.body}"
    end
  end

  def request_headers(source_host, source_category, source_name, data_type, metric_data_format, collected_fields)
    headers = {
        'X-Sumo-Name'     => source_name,
        'X-Sumo-Category' => source_category,
        'X-Sumo-Host'     => source_host,
        'X-Sumo-Client'   => 'fluentd-output'
    }
    if data_type == 'metrics'
      case metric_data_format
      when 'graphite'
        headers['Content-Type'] = 'application/vnd.sumologic.graphite'
      when 'carbon2'
        headers['Content-Type'] = 'application/vnd.sumologic.carbon2'
      when 'prometheus'
        headers['Content-Type'] = 'application/vnd.sumologic.prometheus'
      else
        raise RuntimeError, "Invalid #{metric_data_format}, must be graphite or carbon2 or prometheus"
      end
    end
    unless collected_fields.nil?
      headers['X-Sumo-Fields'] = collected_fields
    end
    return headers
  end

  def ssl_options(verify_ssl)
    verify_ssl==true ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
  end

  def create_http_client(verify_ssl, connect_timeout, proxy_uri, disable_cookies)
    @http                        = HTTPClient.new(proxy_uri)
    @http.ssl_config.verify_mode = ssl_options(verify_ssl)
    @http.connect_timeout        = connect_timeout
    if disable_cookies
      @http.cookie_manager       = nil
    end
  end
end

class Fluent::Plugin::Sumologic < Fluent::Plugin::Output
  # First, register the plugin. NAME is the name of this plugin
  # and identifies the plugin in the configuration file.
  Fluent::Plugin.register_output('sumologic', self)

  helpers :compat_parameters
  DEFAULT_BUFFER_TYPE = "memory"
  LOGS_DATA_TYPE = "logs"
  METRICS_DATA_TYPE = "metrics"
  DEFAULT_DATA_TYPE = LOGS_DATA_TYPE
  DEFAULT_METRIC_FORMAT_TYPE = 'graphite'

  config_param :data_type, :string, :default => DEFAULT_DATA_TYPE
  config_param :metric_data_format, :default => DEFAULT_METRIC_FORMAT_TYPE
  config_param :endpoint, :string, secret: true
  config_param :log_format, :string, :default => 'json'
  config_param :log_key, :string, :default => 'message'
  config_param :source_category, :string, :default => nil
  config_param :source_name, :string, :default => nil
  config_param :source_name_key, :string, :default => 'source_name'
  config_param :source_host, :string, :default => nil
  config_param :verify_ssl, :bool, :default => true
  config_param :delimiter, :string, :default => "."
  config_param :open_timeout, :integer, :default => 60
  config_param :add_timestamp, :bool, :default => true
  config_param :timestamp_key, :string, :default => 'timestamp'
  config_param :proxy_uri, :string, :default => nil
  config_param :disable_cookies, :bool, :default => false
  # https://help.sumologic.com/Manage/Fields
  desc 'Fields string (eg "cluster=payment, service=credit_card") which is going to be added to every record.'
  config_param :custom_fields, :string, :default => nil

  config_section :buffer do
    config_set_default :@type, DEFAULT_BUFFER_TYPE
    config_set_default :chunk_keys, ['tag']
  end

  def initialize
    super
  end

  def multi_workers_ready?
    true
  end

  # This method is called before starting.
  def configure(conf)

    compat_parameters_convert(conf, :buffer)

    unless conf['endpoint'] =~ URI::regexp
      raise Fluent::ConfigError, "Invalid SumoLogic endpoint url: #{conf['endpoint']}"
    end

    unless conf['data_type'].nil?
      unless conf['data_type'] =~ /\A(?:logs|metrics)\z/
        raise Fluent::ConfigError, "Invalid data_type #{conf['data_type']} must be logs or metrics"
      end
    end

    if conf['data_type'].nil? || conf['data_type'] == LOGS_DATA_TYPE
      unless conf['log_format'].nil?
        unless conf['log_format'] =~ /\A(?:json|text|json_merge|fields)\z/
          raise Fluent::ConfigError, "Invalid log_format #{conf['log_format']} must be text, json, json_merge or fields"
        end
      end
    end

    if conf['data_type'] == METRICS_DATA_TYPE && ! conf['metrics_data_type'].nil?
      unless conf['metrics_data_type'] =~ /\A(?:graphite|carbon2|pronetheus)\z/
        raise Fluent::ConfigError, "Invalid metrics_data_type #{conf['metrics_data_type']} must be graphite or carbon2 or prometheus"
      end
    end

    if conf['custom_fields'].nil? || conf['custom_fields'].strip.length == 0
      conf['custom_fields'] = nil
    end

    @sumo_conn = SumologicConnection.new(conf['endpoint'], conf['verify_ssl'], conf['open_timeout'].to_i, conf['proxy_uri'], conf['disable_cookies'])
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
          record = record.merge(JSON.parse(log))
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
    begin
      parser = Yajl::Parser.new
      hash = parser.parse(log[@log_key])
      log[@log_key] = hash
      Yajl.dump(log)
    rescue
      Yajl.dump(log)
    end
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

  def sumo_key(sumo_metadata, chunk)
    source_name = sumo_metadata['source'] || @source_name
    source_name = extract_placeholders(source_name, chunk) unless source_name.nil?

    source_category = sumo_metadata['category'] || @source_category
    source_category = extract_placeholders(source_category, chunk) unless source_category.nil?

    source_host = sumo_metadata['host'] || @source_host
    source_host = extract_placeholders(source_host, chunk) unless source_host.nil?

    fields = sumo_metadata['fields'] || ""
    fields = extract_placeholders(fields, chunk) unless fields.nil?

    { :source_name => "#{source_name}", :source_category => "#{source_category}",
      :source_host => "#{source_host}", :fields => "#{fields}" }
  end

  # Convert timestamp to 13 digit epoch if necessary
  def sumo_timestamp(time)
    time.to_s.length == 13 ? time : time * 1000
  end

  # This method is called every flush interval. Write the buffer chunk
  def write(chunk)
    messages_list = {}

    # Sort messages
    chunk.msgpack_each do |time, record|
      # plugin dies randomly
      # https://github.com/uken/fluent-plugin-elasticsearch/commit/8597b5d1faf34dd1f1523bfec45852d380b26601#diff-ae62a005780cc730c558e3e4f47cc544R94
      next unless record.is_a? Hash
      sumo_metadata = record.fetch('_sumo_metadata', {:source => record[@source_name_key] })
      key           = sumo_key(sumo_metadata, chunk)
      log_format    = sumo_metadata['log_format'] || @log_format

      # Strip any unwanted newlines
      record[@log_key].chomp! if record[@log_key] && record[@log_key].respond_to?(:chomp!)

      case @data_type
      when 'logs'
        case log_format
        when 'text'
          log = record[@log_key]
          unless log.nil?
            log.strip!
          end
        when 'json_merge'
          if @add_timestamp
            record = { @timestamp_key => sumo_timestamp(time) }.merge(record)
          end
          log = dump_log(merge_json(record))
        when 'fields'
          if @add_timestamp
            record = {  @timestamp_key => sumo_timestamp(time) }.merge(record)
          end
          log = dump_log(record)
        else
          if @add_timestamp
            record = { @timestamp_key => sumo_timestamp(time) }.merge(record)
          end
          log = dump_log(record)
        end
      when 'metrics'
        log = record[@log_key]
        unless log.nil?
          log.strip!
        end
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
      source_name, source_category, source_host, fields = key[:source_name], key[:source_category],
        key[:source_host], key[:fields]

      # Merge custom and record fields
      if fields.nil? || fields.strip.length == 0
        fields = @custom_fields
      else
        fields = [fields,@custom_fields].compact.join(",")
      end

      @sumo_conn.publish(
          messages.join("\n"),
          source_host         =source_host,
          source_category     =source_category,
          source_name         =source_name,
          data_type           =@data_type,
          metric_data_format  =@metric_data_format,
          collected_fields    =fields
      )
    end

  end
end
