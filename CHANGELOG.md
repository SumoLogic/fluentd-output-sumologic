# Change Log

All notable changes to this project will be documented in this file. Tracking did not begin until version 1.10.

<a name="1.3.2"></a>
# [1.3.2] (2018-12-05)

* Fix verify SSL bug

<a name="1.3.1"></a>
# [1.3.1] (2018-08-30)

* [Sumo Logic endpoint is a secret](https://github.com/SumoLogic/fluentd-output-sumologic/pull/32)

<a name="1.3.0"></a>
# [1.3.0] (2018-08-08)

<a name="1.2.0"></a>
# [1.2.0] (2018-07-18)

  * add support for multi worker

<a name="1.1.1"></a>
# [1.1.1] (2018-07-12)

  * if `record[@log_key]` is json, parse it as JSON and not as string.  

<a name="1.1.0"></a>
# [1.1.0] (2018-06-29)

  * Add support for sending metrics.

<a name="1.0.3"></a>
# [1.0.3] (2018-05-07)

  * [Fix #26 -- Don't chomp if the message is not chomp-able](https://github.com/SumoLogic/fluentd-output-sumologic/pull/29)

<a name="1.0.2"></a>
# [1.0.2] (2018-04-09)

  * [add option to turn off adding timestamp to logs](https://github.com/SumoLogic/fluentd-output-sumologic/pull/27)

<a name="1.0.1"></a>
# [1.0.1] (2017-12-19)

  * [Add client header for fluentd output](https://github.com/SumoLogic/fluentd-output-sumologic/pull/22)

<a name="1.0.0"></a>
# [1.0.0] (2017-11-06)

  * [Upgrade to 0.14 API, send with ms precision](https://github.com/SumoLogic/fluentd-output-sumologic/pull/12)
  * [Switch to httpclient](https://github.com/SumoLogic/fluentd-output-sumologic/pull/16)
  * [Fix missing variable and improve config example](https://github.com/SumoLogic/fluentd-output-sumologic/pull/17)

<a name="0.0.7"></a>
# [0.0.7] (2017-10-26)

  * [Expand parameters in the output configuration](https://github.com/SumoLogic/fluentd-output-sumologic/pull/14)
  * [add open_timeout option](https://github.com/SumoLogic/fluentd-output-sumologic/pull/15)

<a name="0.0.6"></a>
# [0.0.6] (2017-08-23)

  * Fix 0.0.5

<a name="0.0.5"></a>
# [0.0.5] (2017-08-18)

  * [Ignore garbage records. Fix inspired by other plugins](https://github.com/SumoLogic/fluentd-output-sumologic/pull/7)
  * [Extract the source_name from FluentD's buffer](https://github.com/SumoLogic/fluentd-output-sumologic/pull/8)

<a name="0.0.4"></a>
# [0.0.4] (2017-07-05)

  * [Raise an exception for all non HTTP Success response codes](https://github.com/SumoLogic/fluentd-output-sumologic/pull/5)

<a name="0.0.3"></a>
# [0.0.3] (2016-12-10)

  * Initial Release
