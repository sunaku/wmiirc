require 'logger'
require 'rumai'

module Wmiirc
  extend self

  # path to user's wmii configuration directory
  DIR = File.dirname(File.dirname(__FILE__))

  # keep a log file to aid the user in debugging
  LOG = Logger.new(File.join(DIR, 'wmiirc.log'))

  # add colors to log messages based on severity
  fmt = Logger::Formatter.new
  LOG.formatter = proc do |severity, datetime, progname, msg|
    color = case severity
            when 'DEBUG' then "\e[1;36m"       # bold cyan
            when 'INFO'  then "\e[1;32m"       # bold green
            when 'WARN'  then "\e[1;33m"       # bold yellow
            when 'ERROR' then "\e[1;31m"       # bold red
            when 'FATAL' then "\e[1;30m\e[41m" # bold black on red
            end
    [color, fmt.call(severity, datetime, progname, "\e[0m#{msg}")].join
  end

  # insulation for code in user's configuration
  class Sandbox
    include Rumai
    include Wmiirc

    alias eval instance_eval
  end

  SANDBOX = Sandbox.new
end

require 'wmiirc/import'
require 'wmiirc/handler'
require 'wmiirc/system'
require 'wmiirc/menu'
