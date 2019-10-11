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
  end

  def test_emit_input_text_format_no_sumo_metadata
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
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
                     body: "test",
                     times:1
  end

  def test_emit_input_json_format_no_sumo_metadata
    config = %{
      endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
      source_category test
      source_host     test
      source_name     test
    }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    driver.run do
      driver.feed("output.test", time, {'message' => {"bar" => "foo"}})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                     headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'test', 'X-Sumo-Name'=>'test'},
                     body: /\A{"bar":"foo"}\z/,
                     times:1
  end

  def test_emit_input_text_format_with_sumo_metadata
    config = %{
        endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
        source_category test
        source_host     test
        source_name     test
      }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    ENV['HOST'] = "foo"
    driver.run do
      driver.feed("output.test", time, {'message' => 'some message', '_sumo_metadata' => {
          "host": "#{ENV['HOST']}",
          "source": "${tag}",
          "category": "test",
          "fields": "foo=bar, sumo = logic"
      }})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                    headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'foo', 'X-Sumo-Name'=>'output.test', 'X-Sumo-Fields' => 'foo=bar, sumo = logic'},
                    body: 'some message',
                    times:1
  end

  def test_emit_input_json_format_with_sumo_metadata
    config = %{
        endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
        source_category test
        source_host     test
        source_name     test
      }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    ENV['HOST'] = "foo"
    driver.run do
      driver.feed("output.test", time, {'message' => {"bar" => "foo", "foo" => "shark"}, '_sumo_metadata' => {
          "host": "#{ENV['HOST']}",
          "source": "${tag}",
          "category": "test",
          "fields": "foo=bar, sumo = logic"
      }})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                    headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'foo', 'X-Sumo-Name'=>'output.test', 'X-Sumo-Fields' => 'foo=bar, sumo = logic'},
                    body: /\A{"bar":"foo","foo":"shark"}\z/,
                    times:1
  end

  def test_emit_input_text_format_strip_newlines
    config = %{
        endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
        source_category test
        source_host     test
        source_name     test
      }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    ENV['HOST'] = "foo"
    driver.run do
      driver.feed("output.test", time, {'message' => "\nsome message\n", '_sumo_metadata' => {
          "host": "#{ENV['HOST']}",
          "source": "${tag}",
          "category": "test",
          "fields": "foo=bar, sumo = logic"
      }})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                    headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'foo', 'X-Sumo-Name'=>'output.test', 'X-Sumo-Fields' => 'foo=bar, sumo = logic'},
                    body: 'some message',
                    times:1
  end

  def test_emit_input_json_format_strip_newlines
    config = %{
        endpoint        https://collectors.sumologic.com/v1/receivers/http/1234
        source_category test
        source_host     test
        source_name     test
        log_key         log
      }
    driver = create_driver(config)
    time = event_time
    stub_request(:post, 'https://collectors.sumologic.com/v1/receivers/http/1234')
    ENV['HOST'] = "foo"
    driver.run do
      driver.feed("output.test", time, {'message' => {"log" => "\nhello\n", "foo" => "shark"}, '_sumo_metadata' => {
          "host": "#{ENV['HOST']}",
          "source": "${tag}",
          "category": "test",
          "fields": "foo=bar, sumo = logic"
      }})
    end
    assert_requested :post, "https://collectors.sumologic.com/v1/receivers/http/1234",
                    headers: {'X-Sumo-Category'=>'test', 'X-Sumo-Client'=>'fluentd-output', 'X-Sumo-Host'=>'foo', 'X-Sumo-Name'=>'output.test', 'X-Sumo-Fields' => 'foo=bar, sumo = logic'},
                    body: /\A{"log":"hello","foo":"shark"}\z/,
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
end