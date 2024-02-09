require 'fluent/plugin/output'
require 'net/https'
require 'json'
require 'yajl'
require 'httpclient'
require 'zlib'
require 'stringio'

class SumologicConnection

  attr_reader :http

  COMPRESS_DEFLATE = 'deflate'
  COMPRESS_GZIP = 'gzip'

  def initialize(endpoint, verify_ssl, connect_timeout, send_timeout, proxy_uri, disable_cookies, sumo_client, compress_enabled, compress_encoding, logger)
    @endpoint = endpoint
    @sumo_client = sumo_client
    create_http_client(verify_ssl, connect_timeout, send_timeout, proxy_uri, disable_cookies)
    @compress = compress_enabled
    @compress_encoding = (compress_encoding ||= COMPRESS_GZIP).downcase
    @logger = logger

    unless [COMPRESS_DEFLATE, COMPRESS_GZIP].include? @compress_encoding
      raise "Invalid compression encoding #{@compress_encoding} must be gzip or deflate"
    end
  end

  def publish(raw_data, source_host=nil, source_category=nil, source_name=nil, data_type, metric_data_type, collected_fields, dimensions)
    response = http.post(@endpoint, compress(raw_data), request_headers(source_host, source_category, source_name, data_type, metric_data_type, collected_fields, dimensions))
    unless response.ok?
      raise RuntimeError, "Failed to send data to HTTP Source. #{response.code} - #{response.body}"
    end

    # response is 20x, check response content
    return if response.content.length == 0
    
    # if we get a non-empty response, check it 
    begin
      response_map = JSON.load(response.content)
    rescue JSON::ParserError
      @logger.warn "Error decoding receiver response: #{response.content}"
      return
    end

    # log a warning with the present keys
    response_keys = ["id", "code", "status", "message", "errors"]
    log_params = []
    response_keys.each do |key|
      if response_map.has_key?(key) then
        value = response_map[key]
        log_params.append("#{key}: #{value}")
      end
    end
    log_params_str = log_params.join(", ")
    @logger.warn "There was an issue sending data: #{log_params_str}"
  end

  def request_headers(source_host, source_category, source_name, data_type, metric_data_format, collected_fields, dimensions)
    headers = {
        'X-Sumo-Name'     => source_name,
        'X-Sumo-Category' => source_category,
        'X-Sumo-Host'     => source_host,
        'X-Sumo-Client'   => @sumo_client,
    }

    if @compress
      headers['Content-Encoding'] = @compress_encoding
    end

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

      unless dimensions.nil?
        headers['X-Sumo-Dimensions'] = dimensions
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

  def create_http_client(verify_ssl, connect_timeout, send_timeout, proxy_uri, disable_cookies)
    @http                        = HTTPClient.new(proxy_uri)
    @http.ssl_config.verify_mode = ssl_options(verify_ssl)
    @http.connect_timeout        = connect_timeout
    @http.send_timeout           = send_timeout
    if disable_cookies
      @http.cookie_manager       = nil
    end
  end

  def compress(content)
    if @compress
      if @compress_encoding == COMPRESS_GZIP
        result = gzip(content)
        result.bytes.to_a.pack("c*")
      else
        Zlib::Deflate.deflate(content)
      end
    else
      content
    end
  end # def compress
  
  def gzip(content)
    stream = StringIO.new("w")
    stream.set_encoding("ASCII")
    gz = Zlib::GzipWriter.new(stream)
    gz.mtime=1  # Ensure that for same content there is same output
    gz.write(content)
    gz.close
    stream.string.bytes.to_a.pack("c*")
  end # def gzip
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
  config_param :send_timeout, :integer, :default => 120
  config_param :add_timestamp, :bool, :default => true
  config_param :timestamp_key, :string, :default => 'timestamp'
  config_param :proxy_uri, :string, :default => nil
  config_param :disable_cookies, :bool, :default => false

  config_param :use_internal_retry, :bool, :default => false
  config_param :retry_timeout, :time, :default => 72 * 3600  # 72h
  config_param :retry_max_times, :integer, :default => 0
  config_param :retry_min_interval, :time, :default => 1  # 1s
  config_param :retry_max_interval, :time, :default => 5*60  # 5m

  config_param :max_request_size, :size, :default => 0

  # https://help.sumologic.com/Manage/Fields
  desc 'Fields string (eg "cluster=payment, service=credit_card") which is going to be added to every log record.'
  config_param :custom_fields, :string, :default => nil
  desc 'Name of sumo client which is send as X-Sumo-Client header'
  config_param :sumo_client, :string, :default => 'fluentd-output'
  desc 'Compress payload'
  config_param :compress, :bool, :default => true
  desc 'Encoding method of compresssion (either gzip or deflate)'
  config_param :compress_encoding, :string, :default => SumologicConnection::COMPRESS_GZIP
  # https://help.sumologic.com/03Send-Data/Sources/02Sources-for-Hosted-Collectors/HTTP-Source/Upload-Metrics-to-an-HTTP-Source#supported-http-headers
  desc 'Dimensions string (eg "cluster=payment, service=credit_card") which is going to be added to every metric record.'
  config_param :custom_dimensions, :string, :default => nil

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

    conf['custom_fields'] = validate_key_value_pairs(conf['custom_fields'])
    if conf['custom_fields'].nil?
      conf.delete 'custom_fields'
    end
    unless conf['custom_fields']
      @log.debug "Custom fields: #{conf['custom_fields']}"
    end

    conf['custom_dimensions'] = validate_key_value_pairs(conf['custom_dimensions'])
    if conf['custom_dimensions'].nil?
      conf.delete 'custom_dimensions'
    end
    unless conf['custom_dimensions']
      @log.debug "Custom dimensions: #{conf['custom_dimensions']}"
    end

    # For some reason default is set incorrectly in unit-tests
    if conf['sumo_client'].nil? || conf['sumo_client'].strip.length == 0
      conf['sumo_client'] = 'fluentd-output'
    end

    @sumo_conn = SumologicConnection.new(
      conf['endpoint'],
      conf['verify_ssl'],
      conf['open_timeout'].to_i,
      conf['send_timeout'].to_i,
      conf['proxy_uri'],
      conf['disable_cookies'],
      conf['sumo_client'],
      conf['compress'],
      conf['compress_encoding'],
      log,
      )

    if !conf['max_request_size'].nil? && conf['max_request_size'].to_i <= 0
      conf['max_request_size'] = '0'
    end
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
      hash = JSON.parse(log[@log_key])
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

  # Convert log to string and strip it
  def log_to_str(log)
    if log.is_a?(Array) or log.is_a?(Hash)
      log = Yajl.dump(log)
    end

    unless log.nil?
      log.strip!
    end

    return log
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
          if !record.has_key?(@log_key)
            log.warn "log key `#{@log_key}` has not been found in the log"
          end
          log = log_to_str(record[@log_key])
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
        log = log_to_str(record[@log_key])
      end

      unless log.nil?
        if messages_list.key?(key)
          messages_list[key].push(log)
        else
          messages_list[key] = [log]
        end
      end

    end

    chunk_id = "##{chunk.dump_unique_id_hex(chunk.unique_id)}"
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

      if @max_request_size <= 0
        messages_to_send = [messages]
      else
        messages_to_send = []
        current_message = []
        current_length = 0
        messages.each do |message|
          current_message.push message
          current_length += message.length

          if current_length > @max_request_size
            messages_to_send.push(current_message)
            current_message = []
            current_length = 0
          end
          current_length += 1  # this is for newline
        end
        if current_message.length > 0
          messages_to_send.push(current_message)
        end
      end
      
      messages_to_send.each_with_index do |message, i|
        retries = 0
        start_time = Time.now
        sleep_time = @retry_min_interval

        while true
          common_log_part = "#{@data_type} records with source category '#{source_category}', source host '#{source_host}', source name '#{source_name}', chunk #{chunk_id}, try #{retries}, batch #{i}"

          begin
            @log.debug { "Sending #{message.count}; #{common_log_part}" }

            @sumo_conn.publish(
              message.join("\n"),
                source_host         =source_host,
                source_category     =source_category,
                source_name         =source_name,
                data_type           =@data_type,
                metric_data_format  =@metric_data_format,
                collected_fields    =fields,
                dimensions          =@custom_dimensions
            )
            break
          rescue => e
            if !@use_internal_retry
              raise e
            end
            # increment retries
            retries += 1

            log.warn "error while sending request to sumo: #{e}; #{common_log_part}"
            log.warn_backtrace e.backtrace

            # drop data if
            #   - we reached out the @retry_max_times retries
            #   - or we exceeded @retry_timeout
            if (retries >= @retry_max_times && @retry_max_times > 0) || (Time.now > start_time + @retry_timeout && @retry_timeout > 0)
              log.warn "dropping records; #{common_log_part}"
              break
            end

            log.info "going to retry to send data at #{Time.now + sleep_time}; #{common_log_part}"
            sleep sleep_time

            sleep_time *= 2
            if sleep_time > @retry_max_interval
              sleep_time = @retry_max_interval
            end
          end
        end
      end
    end

  end

  def validate_key_value_pairs(fields)
    if fields.nil?
      return fields
    end

    fields = fields.split(",").select { |field|
      field.split('=').length == 2
    }

    if fields.length == 0
      return nil
    end

    fields.join(',')
  end
end
