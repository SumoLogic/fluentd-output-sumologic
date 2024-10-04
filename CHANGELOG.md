# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.9.1]

Released 2024-10-03

- feat: make receive_timeout configurable [#96](https://github.com/SumoLogic/fluentd-output-sumologic/pull/96)
- chore: add arm support to vagrant [#95](https://github.com/SumoLogic/fluentd-output-sumologic/pull/95)

[1.9.1]: https://github.com/SumoLogic/fluentd-output-sumologic/releases/1.9.1

## [1.9.0]

Released 2024-02-14

- feat: enable compression by default [#87](https://github.com/SumoLogic/fluentd-output-sumologic/pull/87)
- feat: log warning if `log_key` does not exist in log [#86](https://github.com/SumoLogic/fluentd-output-sumologic/pull/86)
- fix: fix how `compress` configuration flag works [#90](https://github.com/SumoLogic/fluentd-output-sumologic/pull/90)

  In `v1.8.0`, setting `compress` flag to either `true` or `false` caused compression to be enabled.
  This is now fixed.

[1.9.0]: https://github.com/SumoLogic/fluentd-output-sumologic/releases/1.9.0

## [1.8.0] (2022-04-22)

- feat: add exponential backoff for sending data [#76](https://github.com/SumoLogic/fluentd-output-sumologic/pull/76)
- feat(max_request_size): add max_request_size to limit size of requests [#78](https://github.com/SumoLogic/fluentd-output-sumologic/pull/78)

[1.8.0]: https://github.com/SumoLogic/fluentd-output-sumologic/releases/1.8.0

## [1.7.5] (2022-04-11)

- refactor: add a debug log on sending [#75](https://github.com/SumoLogic/fluentd-output-sumologic/pull/75)

[1.7.5]: https://github.com/SumoLogic/fluentd-output-sumologic/releases/1.7.5

## [1.7.4] (2021-04-08)

- fix: handle receiver warning messages [#73](https://github.com/SumoLogic/fluentd-output-sumologic/pull/73)

[1.7.4]: https://github.com/SumoLogic/fluentd-output-sumologic/releases/1.7.4

## [1.7.3] (2021-10-19)

- Expose httpclient send_timeout [#66](https://github.com/SumoLogic/fluentd-output-sumologic/pull/68)
- Fix json parsing [#69](https://github.com/SumoLogic/fluentd-output-sumologic/pull/69)

[1.7.3]: https://github.com/SumoLogic/fluentd-output-sumologic/releases/1.7.3

## [1.7.2] (2020-11-23)

- Fix configuration for older fluentd versions [#63](https://github.com/SumoLogic/fluentd-output-sumologic/pull/63)

[1.7.2]: https://github.com/SumoLogic/fluentd-output-sumologic/releases/1.7.2

## [1.7.1] (2020-04-28)

- Fix configuration for older fluentd versions [#63](https://github.com/SumoLogic/fluentd-output-sumologic/pull/63)

[1.7.1]: https://github.com/SumoLogic/fluentd-output-sumologic/releases/1.7.1

## [1.7.0] (2020-04-23)

- Add option for specifing custom fields for logs: [#56](https://github.com/SumoLogic/fluentd-output-sumologic/pull/56)
- Add option for specifing custom dimensions for metrics: [#57](https://github.com/SumoLogic/fluentd-output-sumologic/pull/57)
- Add support for compression: [#58](https://github.com/SumoLogic/fluentd-output-sumologic/pull/58)

[1.7.0]: https://github.com/SumoLogic/fluentd-output-sumologic/releases/1.7.0

## [1.5.0] (2019-06-26)

- Add support for new log format fields: [#49](https://github.com/SumoLogic/fluentd-output-sumologic/pull/49)

[1.5.0]: https://github.com/SumoLogic/fluentd-output-sumologic/releases/1.5.0

## [1.4.1] (2019-03-13)

- Add option for sending metrics in Prometheus format [#39](https://github.com/SumoLogic/fluentd-output-sumologic/pull/39) 
- Use the build-in extract_placeholders method for header expanding [#40](https://github.com/SumoLogic/fluentd-output-sumologic/pull/40)

__NOTE:__ there is a breaking change in the placeholders: `tag_parts[n]` is replaced by `tag[n]` [#47](https://github.com/SumoLogic/fluentd-output-sumologic/issues/47)

[1.4.1]: https://github.com/SumoLogic/fluentd-output-sumologic/releases/1.4.1

## [1.4.0] (2019-01-16)

- [Add timestamp_key, prefer log message when merging](https://github.com/SumoLogic/fluentd-output-sumologic/pull/37)

[1.4.0]: https://github.com/SumoLogic/fluentd-output-sumologic/releases/tag/1.4.0

## [1.3.2] (2018-12-05)

- Fix verify SSL bug

[1.3.2]: https://github.com/SumoLogic/fluentd-output-sumologic/releases/tag/1.3.2

## [1.3.1] (2018-08-30)

- [Sumo Logic endpoint is a secret](https://github.com/SumoLogic/fluentd-output-sumologic/pull/32)

[1.3.1]: https://github.com/SumoLogic/fluentd-output-sumologic/releases/tag/1.3.1

## 1.3.0 (2018-08-08)

## 1.2.0 (2018-07-18)

- add support for multi worker

## 1.1.1 (2018-07-12)

- if `record[@log_key]` is json, parse it as JSON and not as string.  

## 1.1.0 (2018-06-29)

- Add support for sending metrics.

## 1.0.3 (2018-05-07)

- [Fix #26 -- Don't chomp if the message is not chomp-able](https://github.com/SumoLogic/fluentd-output-sumologic/pull/29)

## 1.0.2 (2018-04-09)

- [add option to turn off adding timestamp to logs](https://github.com/SumoLogic/fluentd-output-sumologic/pull/27)

## 1.0.1 (2017-12-19)

- [Add client header for fluentd output](https://github.com/SumoLogic/fluentd-output-sumologic/pull/22)

## 1.0.0 (2017-11-06)

- [Upgrade to 0.14 API, send with ms precision](https://github.com/SumoLogic/fluentd-output-sumologic/pull/12)
- [Switch to httpclient](https://github.com/SumoLogic/fluentd-output-sumologic/pull/16)
- [Fix missing variable and improve config example](https://github.com/SumoLogic/fluentd-output-sumologic/pull/17)

## 0.0.7 (2017-10-26)

- [Expand parameters in the output configuration](https://github.com/SumoLogic/fluentd-output-sumologic/pull/14)
- [add open_timeout option](https://github.com/SumoLogic/fluentd-output-sumologic/pull/15)

## 0.0.6 (2017-08-23)

- Fix 0.0.5

## 0.0.5 (2017-08-18)

- [Ignore garbage records. Fix inspired by other plugins](https://github.com/SumoLogic/fluentd-output-sumologic/pull/7)
- [Extract the source_name from FluentD's buffer](https://github.com/SumoLogic/fluentd-output-sumologic/pull/8)

## 0.0.4 (2017-07-05)

- [Raise an exception for all non HTTP Success response codes](https://github.com/SumoLogic/fluentd-output-sumologic/pull/5)

## 0.0.3 (2016-12-10)

- Initial Release
