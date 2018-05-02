# fluent-plugin-sumologic_output, a plugin for [Fluentd](http://fluentd.org)

This plugin has been designed to output logs to [SumoLogic](http://www.sumologic.com) via a [HTTP collector endpoint](http://help.sumologic.com/Send_Data/Sources/02Sources_for_Hosted_Collectors/HTTP_Source)

## Installation

    gem install fluent-plugin-sumologic_output

## Configuration

Configuration options for fluent.conf are:

* `endpoint` - SumoLogic HTTP Collector URL
* `verify_ssl` - Verify ssl certificate. (default is `true`)
* `source_category` - Set _sourceCategory metadata field within SumoLogic (default is `nil`)
* `source_name` - Set _sourceName metadata field within SumoLogic - overrides source_name_key (default is `nil`)
* `source_name_key` - Set as source::path_key's value so that the source_name can be extracted from Fluentd's buffer (default `source_name`)
* `source_host` - Set _sourceHost metadata field within SumoLogic (default is `nil`)
* `log_format` - Format to post logs into Sumo. (default `json`)
  * text - Logs will appear in SumoLogic in text format (taken from the field specified in `log_key`)
  * json - Logs will appear in SumoLogic in json format.
  * json_merge - Same as json but merge content of `log_key` into the top level and strip `log_key`
* `log_key` - Used to specify the key when merging json or sending logs in text format (default `message`)
* `open_timeout` - Set timeout seconds to wait until connection is opened.
* `add_timestamp` - Add `timestamp` field to logs before sending to sumologic (default `true`)
* `proxy_uri` - Add the `uri` of the `proxy` environment if present.

Reading from the JSON formatted log files with `in_tail` and wildcard filenames:
```
<source>
  @type tail
  format json
  time_key time
  path /path/to/*.log
  pos_file /path/to/pos/ggcp-app.log.pos
  time_format %Y-%m-%dT%H:%M:%S.%NZ
  tag appa.*
  read_from_head false
</source>

<match appa.**>
 @type sumologic
 endpoint https://collectors.sumologic.com/receiver/v1/http/XXXXXXXXXX
 log_format json
 source_category prod/someapp/logs
 source_name AppA
 open_timeout 10
</match>
```

## Example input/output

Assuming following inputs are coming from a log file named `/var/log/appa_webserver.log`
```
{"asctime": "2016-12-10 03:56:35+0000", "levelname": "INFO", "name": "appa", "funcName": "do_something", "lineno": 29, "message": "processing something", "source_ip": "123.123.123.123"}
```

Then output becomes as below within SumoLogic
```
{
    "timestamp":1481343785000,
    "asctime":"2016-12-10 03:56:35+0000",
    "levelname":"INFO",
    "name":"appa",
    "funcName":"do_something",
    "lineno":29,
    "message":"processing something",
    "source_ip":"123.123.123.123"
}
```

## Dynamic Configuration within log message

The plugin supports overriding SumoLogic metadata and log_format parameters within each log message by attaching the field `_sumo_metadata` to the log message.

NOTE: The `_sumo_metadata` field will be stripped before posting to SumoLogic.

Example

```
{
  "name": "appa",
  "source_ip": "123.123.123.123",
  "funcName": "do_something",
  "lineno": 29,
  "asctime": "2016-12-10 03:56:35+0000",
  "message": "processing something",
  "_sumo_metadata": {
    "category": "new_sourceCategory",
    "source": "override_sourceName",
    "host": "new_sourceHost",
    "log_format": "merge_json_log"
  },
  "levelname": "INFO"
}
```
