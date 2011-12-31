require 'wmiirc'
require 'wmiirc/config'
require 'wmiirc/system'
require 'kwalify'

module Wmiirc
module Loader
class << self

  CONFIG_FILE = File.join(DIR, 'config.yaml')
  CONFIG_DUMP_FILE = File.join(DIR,'config.dump')

  CONFIG_SCHEMA_FILE = File.join(DIR, 'schema.yaml')
  CONFIG_SCHEMA = YAML.load_file(CONFIG_SCHEMA_FILE)
  CONFIG_VALIDATOR = Kwalify::Validator.new(CONFIG_SCHEMA)
  CONFIG_PARSER = Kwalify::Yaml::Parser.new(CONFIG_VALIDATOR)

  def run
    LOG.info 'start'

    log_standard_outputs
    terminate_other_instances
    load_user_config
    spawn 'witray' # relaunch to accomodate changes in screen resolution
    enter_event_loop

  rescue SystemExit
    # ignore it; the program wants to terminate

  rescue Errno::EPIPE => e
    LOG.error e
    LOG.info 'Lost connection to wmii.  Attempting to reconnect...'
    reload

  rescue Exception => e
    LOG.error e
    allow_user_rescue e

  ensure
    LOG.info 'stop'
  end

  def reload
    LOG.info 'reload'
    Wmiirc.launch! File.expand_path($0)
  end

  private

  def log_standard_outputs
    [STDOUT, STDERR].each do |output|
      output.singleton_class.class_eval do
        alias _547c1ae1_b571_4273_8037_d0c829856680 write
        def write string
          Wmiirc::LOG << string
          _547c1ae1_b571_4273_8037_d0c829856680 string
        end
        alias << write # update alias to use new method
      end
    end
  end

  def terminate_other_instances
    Rumai.fs.event.write 'Start wmiirc'

    Wmiirc.event 'Start' do |arg|
      exit if arg == 'wmiirc'
    end
  end

  def load_user_session
    session_file = File.join(DIR, 'session.dump')

    require 'fileutils'
    FileUtils.touch session_file
    File.open(session_file).flock(File::LOCK_EX) # auto released on exit

    session =
      begin
        YAML.load_file(session_file).to_hash
      rescue => e
        LOG.error e
        Hash.new
      end

    at_exit do
      File.write session_file, session.to_yaml
    end

    Wmiirc.const_set :SESSION, session
  end

  def load_user_requires
    Array(CONFIG['require']).each do |library|
      if library.kind_of? Hash
        library.each do |gem_name, gem_version|
          gem gem_name, *Array(gem_version)
          require gem_name
        end
      else
        require library
      end
    end
  end

  def load_user_config
    config = Config.new(CONFIG_FILE)
    File.write CONFIG_DUMP_FILE, config.to_yaml

    errors = CONFIG_VALIDATOR.validate(config)
    if errors and not errors.empty?
      raise ArgumentError, "invalid configuration:\n#{errors.join("\n")}"
    end

    Wmiirc.const_set :CONFIG, config
    load_user_requires
    load_user_session
    config.apply
  end

  def enter_event_loop
    Rumai.fs.event.each_line do |line|
      line.split(/\n/).each do |call|
        name, args = call.split(' ', 2)
        argv = args.to_s.split(' ')

        Wmiirc.event name, *argv
      end
    end
  end

  def allow_user_rescue error
    spawn 'xterm'

    IO.popen('xmessage -nearmouse -file - -buttons Recover,Ignore -print', 'w+') do |f|
      f.puts error.inspect, error.backtrace
      f.close_write

      reload if f.read.chomp == 'Recover'
    end
  end

end
end
end
