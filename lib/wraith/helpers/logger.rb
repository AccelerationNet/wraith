# Logging Module, credit: http://stackoverflow.com/a/6768164
require "logger"

if !$logger
  $logger  = Logger.new(STDOUT)
  $logger.formatter = proc do |severity, _datetime, _progname, msg|
    (severity == "INFO") ? "#{msg}\n" : "#{severity}: #{msg}\n"
  end
end


module Logging
  def logger
    $logger
  end
  # Global, memoized, lazy initialized instance of a logger
  def self.logger
    $logger
  end
end
