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
        load_user_session
        load_user_config
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

      ##
      # Tries to find the given file inside WMII_CONFPATH or
      # the user's personal wmii configuration directory.
      #
      # Returns nil if the file could not be found.
      #
      def find file
        unless defined? @find_dirs_glob
          base_dirs = ENV['WMII_CONFPATH'].to_s.split(/:+/).unshift(DIR)
          ruby_dirs = base_dirs.map {|dir| File.join(dir, 'ruby') }
          @find_dirs_glob = '{' + base_dirs.zip(ruby_dirs).join(',') + '}'
        end

        Dir["#{@find_dirs_glob}/#{file}"].first
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

        # wait for other instances to exit
        # so that we can read their session
        # data after they finish writing it
        sleep 0.5 # FIXME: race condition
      end

      def load_user_session
        session_file = File.join(DIR, 'session.yaml')

        session =
          begin
            YAML.load_file session_file
          rescue => e
            LOG.error e
            {}
          end

        at_exit do
          File.open(session_file, 'w') do |file|
            file.write session.to_yaml
          end
        end

        Wmiirc.const_set :SESSION, session
      end

      def load_user_config
        config = Config.new('config')
        Wmiirc.const_set :CONFIG, config
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
