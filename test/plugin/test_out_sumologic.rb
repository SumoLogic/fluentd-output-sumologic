require "test-unit"
require "fluent/test"
require "fluent/test/driver/output"
require "fluent/test/helpers"
require 'webmock/test_unit'
require 'fluent/plugin/out_sumologic'

class SumologicOutput < Test::Unit::TestCase
  include Fluent::Test::Helpers

  def setup
    Fluent::Test.setup
  end

  def create_driver(conf = CONFIG)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::Sumologic).configure(conf)
  end

  def test_no_endpoint_configure
    config = %{}
    exception = assert_raise(Fluent::ConfigError) {create_driver(config)}
    assert_equal("Invalid SumoLogic endpoint url: ", exception.message)
  end

  def test_invalid_data_type_configure
    config = %{
      endpoint      https://SUMOLOGIC_URL
      data_type     'foo'
    }
    exception = assert_raise(Fluent::ConfigError) {create_driver(config)}
    assert_equal("Invalid data_type foo must be logs or metrics", exception.message)
  end

  def test_invalid_log_format_configure
    config = %{
      endpoint      https://SUMOLOGIC_URL
      log_format    foo
    }
    exception = assert_raise(Fluent::ConfigError) {create_driver(config)}
    assert_equal("Invalid log_format foo must be text, json, json_merge or fields", exception.message)
  end

  def test_invalid_metrics_data_type
    config = %{
      endpoint            https://SUMOLOGIC_URL
      data_type           metrics
      metrics_data_type   foo
    }
    exception = assert_raise(Fluent::ConfigError) {create_driver(config)}
    assert_equal("Invalid metrics_data_type foo must be graphite or carbon2 or prometheus", exception.message)
  end

  def test_default_configure
    config = %{
      endpoint        https://SUMOLOGIC_URL
    }
    instance = create_driver(config).instance

    assert_equal instance.data_type, 'logs'
    assert_equal instance.metric_data_format, 'graphite'
    assert_equal instance.endpoint, 'https://SUMOLOGIC_URL'
    assert_equal instance.log_format, 'json'
    assert_equal instance.log_key, 'message'
    assert_equal instance.source_category, nil
    assert_equal instance.source_name, nil
    assert_equal instance.source_name_key, 'source_name'
    assert_equal instance.source_host, nil
    assert_equal instance.verify_ssl, true
    assert_equal instance.delimiter, '.'
    assert_equal instance.open_timeout, 60
    assert_equal instance.add_timestamp, true
    assert_equal instance.timestamp_key, 'timestamp'
    assert_equal instance.proxy_uri, nil
    assert_equal instance.disable_cookies, false
    assert_equal instance.sumo_client, 'fluentd-output'
    assert_equal instance.compress_encoding, 'gzip'
  end

  def test_emit_text
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      log_format      text
      source_category test
      source_host     test
      source_name     test

    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'foo' => 'bar', 'message' => 'test'})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                     body: "test",
                     times:1
  end

  def test_emit_text_custom_sumo_client
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      log_format      text
      source_category test
      source_host     test
      source_name     test
      sumo_client     'fluentd-custom-sender'

    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'foo' => 'bar', 'message' => 'test'})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-custom-sender', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                     body: "test",
                     times:1
  end

  def test_emit_json
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      log_format      json
      source_category test
      source_host     test
      source_name     test

    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'foo' => 'bar', 'message' => 'test'})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                     body: /\A{"timestamp":\d+.,"foo":"bar","message":"test"}\z/,
                     times:1
  end

  def test_emit_empty_fields
    config = %{
	      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
	      log_format      fields
	      source_category test
	      source_host     test
	      source_name     test

	    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'message' => 'test'})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                     body: /\A{"timestamp":\d+.,"message":"test"}\z/,
                     times:1
  end

  def test_emit_json_double_encoded
    config = %{
      endpoint        https://endpoint3.collection.us2.sumologic.com/receiver/v1/http/1234
      log_format      json
      source_category test
      source_host     test
      source_name     test

    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://endpoint3.collection.us2.sumologic.com/receiver/v1/http/1234')
    driver.run do
      driver.feed("output.test", time, {'message' => '{"bar":"foo"}'})
    end
    assert_requested :post, "https://endpoint3.collection.us2.sumologic.com/receiver/v1/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                     body: /\A{"timestamp":\d+.,"message":{"bar":"foo"}}\z/,
                     times:1
  end

  def test_emit_text_format_as_json
    config = %{
      endpoint        https://endpoint3.collection.us2.sumologic.com/receiver/v1/http/1234
      log_format      json
      source_category test
      source_host     test
      source_name     test

    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://endpoint3.collection.us2.sumologic.com/receiver/v1/http/1234')
    driver.run do
      driver.feed("output.test", time, {'message' => 'some message'})
    end
    assert_requested :post, "https://endpoint3.collection.us2.sumologic.com/receiver/v1/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                     body: /\A{"timestamp":\d+.,"message":"some message"}\z/,
                     times:1
  end

  def test_emit_json_merge
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      log_format      json_merge
      source_category test
      source_host     test
      source_name     test

    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'foo' => 'bar', 'message' => '{"foo2":"bar2"}'})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                     body: /\A{"timestamp":\d+,"foo":"bar","foo2":"bar2"}\z/,
                     times:1
  end

  def test_emit_json_merge_timestamp
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      log_format      json_merge
      source_category test
      source_host     test
      source_name     test

    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'message' => '{"timestamp":123}'})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                     body: /\A{"timestamp":123}\z/,
                     times:1
  end

  def test_emit_with_sumo_metadata_with_fields_json_format
    config = %{
	      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
	      log_format      json
	    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    ENV['HOST'] = "foo"
    driver.run do
      driver.feed("output.test", time, {'foo' => 'bar', 'message' => 'test', '_sumo_metadata' => {
          "host": "#{ENV['HOST']}",
          "source": "${tag}",
          "category": "test",
          "fields": "foo=bar, sumo = logic"
      }})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'foo', 'X-Sumo-Name'=>'output.test'},
                     body: /\A{"timestamp":\d+.,"foo":"bar","message":"test"}\z/,
                     times:1
  end

  def test_emit_with_sumo_metadata_with_fields_fields_format
    config = %{
	      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
	      log_format      fields
	    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    ENV['HOST'] = "foo"
    driver.run do
      driver.feed("output.test", time, {'foo' => 'shark', 'message' => 'test', '_sumo_metadata' => {
          "host": "#{ENV['HOST']}",
          "source": "${tag}",
          "category": "test",
          "fields": "foo=bar, sumo = logic"
      }})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'foo', 'X-Sumo-Name'=>'output.test', 'X-Sumo-Fields' => 'foo=bar, sumo = logic'},
                     body: /\A{"timestamp":\d+.,"foo":"shark","message":"test"}\z/,
                     times:1
  end

  def test_emit_with_sumo_metadata_with_fields_and_custom_fields_fields_format
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      log_format      fields
      custom_fields   "lorem=ipsum,dolor=amet"
    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    ENV['HOST'] = "foo"
    driver.run do
      driver.feed("output.test", time, {'foo' => 'shark', 'message' => 'test', '_sumo_metadata' => {
          "host": "#{ENV['HOST']}",
          "source": "${tag}",
          "category": "test",
          "fields": "foo=bar, sumo = logic"
      }})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'foo', 'X-Sumo-Name'=>'output.test', 'X-Sumo-Fields' => 'foo=bar, sumo = logic,lorem=ipsum,dolor=amet'},
                     body: /\A{"timestamp":\d+.,"foo":"shark","message":"test"}\z/,
                     times:1
  end

  def test_emit_with_sumo_metadata_with_fields_and_empty_custom_fields_fields_format
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      log_format      fields
      custom_fields   ""
    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    ENV['HOST'] = "foo"
    driver.run do
      driver.feed("output.test", time, {'foo' => 'shark', 'message' => 'test', '_sumo_metadata' => {
          "host": "#{ENV['HOST']}",
          "source": "${tag}",
          "category": "test",
          "fields": "foo=bar, sumo = logic"
      }})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'foo', 'X-Sumo-Name'=>'output.test', 'X-Sumo-Fields' => 'foo=bar, sumo = logic'},
                     body: /\A{"timestamp":\d+.,"foo":"shark","message":"test"}\z/,
                     times:1
  end

  def test_emit_with_sumo_metadata_with_empty_fields_and_custom_fields_fields_format
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      log_format      fields
      custom_fields   "lorem=ipsum,invalid"
    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    ENV['HOST'] = "foo"
    driver.run do
      driver.feed("output.test", time, {'foo' => 'shark', 'message' => 'test', '_sumo_metadata' => {
          "host": "#{ENV['HOST']}",
          "source": "${tag}",
          "category": "test",
          "fields": ""
      }})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'foo', 'X-Sumo-Name'=>'output.test', 'X-Sumo-Fields' => 'lorem=ipsum'},
                     body: /\A{"timestamp":\d+.,"foo":"shark","message":"test"}\z/,
                     times:1
  end

  def test_emit_with_sumo_metadata
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      log_format      json
    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    ENV['HOST'] = "foo"
    driver.run do
      driver.feed("output.test", time, {'foo' => 'bar', 'message' => 'test', '_sumo_metadata' => {
          "host": "#{ENV['HOST']}",
          "source": "${tag}",
          "category": "${tag[1]}"
      }})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'foo', 'X-Sumo-Name'=>'output.test'},
                     body: /\A{"timestamp":\d+.,"foo":"bar","message":"test"}\z/,
                     times:1
  end

  def test_emit_json_no_timestamp
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      log_format      json
      source_category test
      source_host     test
      source_name     test
      add_timestamp   false
    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'foo' => 'bar', 'message' => 'test'})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                     body: /\A{"foo":"bar","message":"test"}\z/,
                     times:1
  end

  def test_emit_json_timestamp_key
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      log_format      json
      source_category test
      source_host     test
      source_name     test
      timestamp_key   ts
    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'message' => 'test'})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                     body: /\A{"ts":\d+.,"message":"test"}\z/,
                     times:1
  end

  def test_emit_graphite
    config = %{
      endpoint            https://collectors.sumologic.com/v1/receivers/http/1234
      data_type           metrics
      metric_data_format  graphite
      source_category     test
      source_host         test
      source_name         test
    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'message' =>'prod.lb-1.cpu 87.2 1501753030'})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test', 'Content-Type'=>'application/vnd.sumologic.graphite'},
                     body: /\Aprod.lb-1.cpu 87.2 1501753030\z/,
                     times:1
  end

  def test_emit_carbon
    config = %{
      endpoint            https://collectors.sumologic.com/v1/receivers/http/1234
      data_type           metrics
      metric_data_format  carbon2
      source_category     test
      source_host         test
      source_name         test
    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'message' =>'cluster=prod node=lb-1 metric=cpu  ip=2.2.3.4 team=infra 87.2 1501753030'})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test', 'Content-Type'=>'application/vnd.sumologic.carbon2'},
                     body: /\Acluster=prod node=lb-1 metric=cpu  ip=2.2.3.4 team=infra 87.2 1501753030\z/,
                     times:1
  end

  def test_emit_prometheus
    config = %{
      endpoint            https://collectors.sumologic.com/v1/receivers/http/1234
      data_type           metrics
      metric_data_format  prometheus
      source_category     test
      source_host         test
      source_name         test
    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'message' =>'cpu{cluster="prod", node="lb-1"} 87.2 1501753030'})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test', 'Content-Type'=>'application/vnd.sumologic.prometheus'},
                     body: 'cpu{cluster="prod", node="lb-1"} 87.2 1501753030',
                     times:1
  end

  def test_emit_prometheus_with_custom_dimensions
    config = %{
      endpoint            https://collectors.sumologic.com/v1/receivers/http/1234
      data_type           metrics
      metric_data_format  prometheus
      source_category     test
      source_host         test
      source_name         test
      custom_dimensions   'foo=bar, dolor=sit,amet,test'
    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'message' =>'cpu{cluster="prod", node="lb-1"} 87.2 1501753030'})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {
                       'X-Sumo-Category'=>'test',
                       'X-Sumo-Client'=>'fluentd-output',
                       'X-Sumo-Host'=>'test',
                       'X-Sumo-Name'=>'test',
                       'X-Sumo-Dimensions'=>'foo=bar, dolor=sit',
                       'Content-Type'=>'application/vnd.sumologic.prometheus'},
                     body: 'cpu{cluster="prod", node="lb-1"} 87.2 1501753030',
                     times:1
  end

  def test_emit_prometheus_with_empty_custom_metadata
    config = %{
      endpoint            https://collectors.sumologic.com/v1/receivers/http/1234
      data_type           metrics
      metric_data_format  prometheus
      source_category     test
      source_host         test
      source_name         test
      custom_metadata     "    "
    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'message' =>'cpu{cluster="prod", node="lb-1"} 87.2 1501753030'})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {
                       'X-Sumo-Category'=>'test',
                       'X-Sumo-Client'=>'fluentd-output',
                       'X-Sumo-Host'=>'test',
                       'X-Sumo-Name'=>'test',
                       'Content-Type'=>'application/vnd.sumologic.prometheus'},
                     body: 'cpu{cluster="prod", node="lb-1"} 87.2 1501753030',
                     times:1
  end

  def test_batching_same_headers
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      log_format      json
      source_category test
      source_host     test
      source_name     test
    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'message' => 'test1'})
      driver.feed("output.test", time, {'message' => 'test2'})
    end
    assert_requested  :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                      headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                      body: /\A{"timestamp":\d+.,"message":"test1"}\n{"timestamp":\d+.,"message":"test2"}\z/,
                      times:1
  end

  def test_batching_different_headers
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      log_format      json
      source_category test
      source_host     test
      source_name     test
    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'message' => 'test1', '_sumo_metadata' => {"category": "cat1"}})
      driver.feed("output.test", time, {'message' => 'test2', '_sumo_metadata' => {"category": "cat2"}})
    end
    assert_requested  :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                      headers: {'X-Sumo-Category'=>'cat1', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                      body: /\A{"timestamp":\d+.,"message":"test1"}\z/,
                      times:1
    assert_requested  :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                      headers: {'X-Sumo-Category'=>'cat2', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                      body: /\A{"timestamp":\d+.,"message":"test2"}\z/,
                      times:1
  end

  def test_batching_different_fields
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      log_format      fields
      source_category test
      source_host     test
      source_name     test
    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'message' => 'test1'})
      driver.feed("output.test", time, {'message' => 'test2', '_sumo_metadata' => {"fields": "foo=bar"}})
      driver.feed("output.test", time, {'message' => 'test3', '_sumo_metadata' => {"fields": "foo=bar,sumo=logic"}})
      driver.feed("output.test", time, {'message' => 'test4', '_sumo_metadata' => {"fields": "foo=bar,master_url=https://100.64.0.1:443"}})
    end
    assert_requested  :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                      headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                      body: /\A{"timestamp":\d+.,"message":"test1"}\z/,
                      times:1
    assert_requested  :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                      headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test', 'X-Sumo-Fields' => 'foo=bar'},
                      body: /\A{"timestamp":\d+.,"message":"test2"}\z/,
                      times:1
    assert_requested  :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                      headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test', 'X-Sumo-Fields' => 'foo=bar,sumo=logic'},
                      body: /\A{"timestamp":\d+.,"message":"test3"}\z/,
                      times:1
    assert_requested  :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                      headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test', 'X-Sumo-Fields' => 'foo=bar,master_url=https://100.64.0.1:443'},
                      body: /\A{"timestamp":\d+.,"message":"test4"}\z/,
                      times:1
  end

  def test_emit_json_merge_timestamp_compress_deflate
    config = %{
      endpoint          https://collectors.sumologic.com/v1/receivers/http/1234
      log_format        json_merge
      source_category   test
      source_host       test
      source_name       test
      compress          true
      compress_encoding deflate

    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'message' => '{"timestamp":123}'})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test', 'Content-Encoding'=>'deflate'},
                     body: "\x78\x9c\xab\x56\x2a\xc9\xcc\x4d\x2d\x2e\x49\xcc\x2d\x50\xb2\x32\x34\x32\xae\x05\x00\x38\xb0\x05\xe1".force_encoding("ASCII-8BIT"),
                     times:1
  end

  def test_emit_json_merge_timestamp_compress_gzip
    config = %{
      endpoint          https://collectors.sumologic.com/v1/receivers/http/1234
      log_format        json_merge
      source_category   test
      source_host       test
      source_name       test
      compress          true

    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'message' => '{"timestamp":1234}'})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test', 'Content-Encoding'=>'gzip'},
                     body: "\x1f\x8b\x08\x00\x01\x00\x00\x00\x00\x03\xab\x56\x2a\xc9\xcc\x4d\x2d\x2e\x49\xcc\x2d\x50\xb2\x32\x34\x32\x36\xa9\x05\x00\xfe\x53\xbe\x14\x12\x00\x00\x00".force_encoding("ASCII-8BIT"),
                     times:1
  end

  def test_emit_text_from_array
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      log_format      text
      source_category test
      source_host     test
      source_name     test

    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'foo' => 'bar', 'message' => ['test', 'test2']})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                     body: '["test","test2"]',
                     times:1
  end

  def test_emit_text_from_dict
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      log_format      text
      source_category test
      source_host     test
      source_name     test

    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'foo' => 'bar', 'message' => {'test': 'test2', 'test3': 'test4'}})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                     body: '{"test":"test2","test3":"test4"}',
                     times:1
  end

  def test_emit_fields_string_based
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      log_format      fields
      source_category test
      source_host     test
      source_name     test
  
    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'message' => '{"foo": "bar", "message": "test"}'})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                     body: /\A{"timestamp":\d+.,"message":{"foo":"bar","message":"test"}}\z/,
                     times:1
  end
  
  def test_emit_fields_invalid_json_string_based_1
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      log_format      fields
      source_category test
      source_host     test
      source_name     test
  
    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'message' => '{"foo": "bar", "message": "test"'})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                     body: /\A{"timestamp":\d+.,"message":"{\\"foo\\": \\"bar\\", \\"message\\": \\"test\\""}\z/,
                     times:1
  end
  
  def test_emit_fields_invalid_json_string_based_2
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      log_format      fields
      source_category test
      source_host     test
      source_name     test
  
    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'message' => '{"foo": "bar", "message"'})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                     body: /\A{"timestamp":\d+.,"message":"{\\"foo\\": \\"bar\\", \\"message\\""}\z/,
                     times:1
  end
  
  def test_emit_fields_invalid_json_string_based_3
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      log_format      fields
      source_category test
      source_host     test
      source_name     test
  
    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'message' => '"foo\": \"bar\", \"mess'})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                     body: /\A{"timestamp":\d+.,"message":"\\"foo\\\\\\": \\\\\\"bar\\\\\\", \\\\\\"mess"}\z/,
                     times:1
  end

  def test_warning_response_from_receiver
    endpoint = "https://collectors.sumologic.com/v1/receivers/http/1234"
    config = %{
      endpoint #{endpoint}
    }
    testdata = [
      [
        '{"id":"1TIRY-KGIVX-TPQRJ","errors":[{"code":"internal.error","message":"Internal server error."}]}', 
        'There was an issue sending data: id: 1TIRY-KGIVX-TPQRJ, errors: [{"code"=>"internal.error", "message"=>"Internal server error."}]'
      ],
      [
        '{"id":"1TIRY-KGIVX-TPQRX","code": 200, "status": "Fields dropped", "message": "Dropped fields above the 30 field limit"}', 
        'There was an issue sending data: id: 1TIRY-KGIVX-TPQRX, code: 200, status: Fields dropped, message: Dropped fields above the 30 field limit'
      ],
    ]
    time = event_time

    testdata.each do |data, log|
      driver = create_driver(config)
      stub_request(:post, endpoint).to_return(body: data, headers: {content_type: 'application/json'})
      driver.run do
        driver.feed("test", time, {"message": "test"})
      end
      assert_equal driver.logs.length, 1
      assert driver.logs[0].end_with?(log + "\n")
    end
  end

  def test_resend
    endpoint = "https://collectors.sumologic.com/v1/receivers/http/1234"
    config = %{
      endpoint #{endpoint}
      retry_min_interval 0s
      retry_max_times 3
      use_internal_retry true
    }
    time = event_time

    driver = create_driver(config)
    stub_request(:post, endpoint).to_return(
      {status: 500, headers: {content_type: 'application/json'}},
      {status: 200, headers: {content_type: 'application/json'}}
    )
    driver.run do
      driver.feed("test", time, {"message": "test"})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     body: /\A{"timestamp":\d+.,"message":"test"}\z/,
                     times:2
  end

  def test_resend_failed
    endpoint = "https://collectors.sumologic.com/v1/receivers/http/1234"
    config = %{
      endpoint #{endpoint}
      retry_min_interval 0s
      retry_max_times 15
      use_internal_retry true
    }
    time = event_time

    driver = create_driver(config)
    stub_request(:post, endpoint).to_return(
      status: 500, headers: {content_type: 'application/json'}
    )
    driver.run do
      driver.feed("test", time, {"message": "test"})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     body: /\A{"timestamp":\d+.,"message":"test"}\z/,
                     times:15
  end

  def test_resend_forever
    endpoint = "https://collectors.sumologic.com/v1/receivers/http/1234"
    config = %{
      endpoint #{endpoint}
      retry_min_interval 0s
      retry_max_times 0
      retry_timeout 0s
      use_internal_retry true
    }
    time = event_time

    driver = create_driver(config)
    stub_request(:post, endpoint).to_return(
      *[{status: 500, headers: {content_type: 'application/json'}}]*123,
      {status: 200, headers: {content_type: 'application/json'}}
    )
    driver.run do
      driver.feed("test", time, {"message": "test"})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     body: /\A{"timestamp":\d+.,"message":"test"}\z/,
                     times:124
  end

  def test_skip_retry
    endpoint = "https://collectors.sumologic.com/v1/receivers/http/1234"
    config = %{
      endpoint #{endpoint}
    }
    time = event_time

    driver = create_driver(config)
    stub_request(:post, endpoint).to_return(status: 500, headers: {content_type: 'application/json'})

    exception = assert_raise(RuntimeError) {
      driver.run do
        driver.feed("test", time, {"message": "test"})
      end
    }
    assert_equal("Failed to send data to HTTP Source. 500 - ", exception.message)
  end

end
