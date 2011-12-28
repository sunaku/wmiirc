require 'wmiirc'
require 'wmiirc/config'
require 'wmiirc/system'

module Wmiirc
  module Loader
    class << self

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
        Wmiirc.launch File.expand_path($0)
      end

      private

      ##
      # Tee standard outputs into log.
      #
      def log_standard_outputs
        [STDOUT, STDERR].each do |output|
          (class << output; self; end).class_eval do
            alias __write__ write

            def write string
              Wmiirc::LOG << string
              __write__ string
            end

            alias << write
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
          File.open(session_file, 'w') do |file|
            file.write session.to_yaml
          end
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

      def dump_user_config
        File.open(File.join(DIR, 'config.dump'), 'w') do |file|
          file.write CONFIG.to_yaml
        end
      end

      def load_user_config
        config = Config.new('config')
        Wmiirc.const_set :CONFIG, config
        load_user_requires
        load_user_session
        dump_user_config
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
