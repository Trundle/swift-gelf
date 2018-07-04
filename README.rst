.. image:: https://img.shields.io/github/license/Trundle/swift-gelf.svg
   :target: https://tldrlegal.com/l/apache2

.. image:: https://travis-ci.org/Trundle/swift-gelf.svg?branch=master
   :target: https://travis-ci.org/Trundle/swift-gelf

==========
swift-gelf
==========

A `GELF`_ library for Swift, without a nifty name.


Design
======

A ``Logger`` is simply a consumer of logging events. It's highly encouraged to
think in terms of logging events while using the library and not in terms of
logging messages. Events should be enriched with individual key-value pairs.

A logger consumes an event via a configured pipeline. Each stage in the
pipeline can modify the event or even drop it (for example in case a stage
is a filter for events according to some criteria). The output of every stage
is used as input for the next stage. At the end of a pipeline is typically
some appender, for example the ``GELFAppender`` for appending the events to a
GELF server.

The library comes with a few predefined pipeline stages that can be used:

* ``Branch``: Splits a pipeline into multiple pipelines. Useful for example
  when you want a filter that only applies to a single appender.
* ``ThresholdFilter``: Filters log events based on their log level
* ``PrintAppender``: Writes a log event to stdout and returns it
* ``GELFAppender``: Sends log events to a GELF server


How to use
==========

Loggers can be obtained via the ``getLogger`` function. It returns a logger
that processes log messages via a globally configured pipeline. The pipeline
can be set via ``configureLogging(pipeline:)``.

See ``Sources/Sample/main.swift`` for a sample program how the library can be
used.


License
=======

swift-gelf is released under the Apache License, Version 2.0 (see the
``LICENSE`` file or http://www.apache.org/licenses/LICENSE-2.0.html).


.. _GELF: http://docs.graylog.org/en/2.4/pages/gelf.html