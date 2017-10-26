require 'helper'
require 'fluent/test/driver/output'

class SumologicOutput < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
    require 'fluent/plugin/out_sumologic'
    @driver = nil
    log = Fluent::Engine.log
    log.out.logs.slice!(0, log.out.logs.length)
  end

  def driver(conf='')
    @driver ||= Fluent::Test::Driver::Output.new(Sumologic).configure(conf)
  end

  def test_configure
    config = %{
      endpoint        https://SUMOLOGIC_URL
      log_format      text
      log_key         LOG_KEY
      source_category SOURCE_CATEGORY
      source_name     SOURCE_NAME
      source_name_key SOURCE_NAME_KEY
      source_host     SOURCE_HOST
      verify_ssl      false
      open_timeout    10
    }
    instance = driver(config).instance

    assert_equal instance.endpoint, 'https://SUMOLOGIC_URL'
    assert_equal instance.log_format, 'text'
    assert_equal instance.log_key, 'LOG_KEY'
    assert_equal instance.source_category, 'SOURCE_CATEGORY'
    assert_equal instance.source_name, 'SOURCE_NAME'
    assert_equal instance.source_name_key, 'SOURCE_NAME_KEY'
    assert_equal instance.source_host, 'SOURCE_HOST'
    assert_equal instance.verify_ssl, false
    assert_equal instance.open_timeout, 10
  end
end
