require 'logger'

require 'rubygems'
gem 'rumai', '>= 3.2.0', '< 4'
require 'rumai'

module Rumai
  # TODO: move this upstream
  extend self
end

module Wmiirc
  extend self

  # path to user's wmii configuration directory
  DIR = File.dirname(File.dirname(__FILE__))

  # keep a log file to aid the user in debugging
  LOG = Logger.new(File.join(DIR, 'wmiirc.log'))

  # insulation for code in user's configuration
  class Sandbox
    include Rumai
    include Wmiirc

    alias eval instance_eval
  end

  SANDBOX = Sandbox.new
end

require 'wmiirc/handler'
require 'wmiirc/system'
require 'wmiirc/menu'
