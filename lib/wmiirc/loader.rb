#--
# Copyright protects this work.
# See LICENSE file for details.
#++

require 'wmiirc'
require 'wmiirc/config'

module Wmiirc
  module Loader
    class << self

      ##
      # Executes the user's wmii configuration.
      #
      def run
        LOG.info 'birth'

        log_standard_outputs
        terminate_other_instances
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
        LOG.info 'death'
      end

      ##
      # Reloads the entire wmii configuration.
      #
      def reload
        LOG.info 'reload'
        exec $0
      end

      ##
      # Tries to find the given file inside WMII_CONFPATH or
      # the user's personal wmii configuration directory.
      #
      # Returns nil if the file could not be found.
      #
      def find file
        base_dirs = ENV['WMII_CONFPATH'].to_s.split(/:+/).push(DIR)
        ruby_dirs = base_dirs.map {|dir| File.join(dir, 'ruby') }

        Dir["{#{base_dirs.zip(ruby_dirs).join(',')}}/#{file}"].first
      end

      private

      def log_standard_outputs
        [STDOUT, STDERR].each do |stream|
          original = stream.method(:write)

          (class << stream; self; end).class_eval do
            define_method :write do |s|
              LOG << s
              original.call s
            end

            alias_method :<<, :write
          end
        end
      end

      def terminate_other_instances
        Rumai.fs.event.write 'Start wmiirc'

        Wmiirc.event 'Start' do |arg|
          exit if arg == 'wmiirc'
        end
      end

      def load_user_config
        config = Config.new('sunaku')
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
        system 'xterm &'

        IO.popen('xmessage -nearmouse -file - -buttons Recover,Ignore -print', 'w+') do |f|
          f.puts error.inspect, error.backtrace
          f.close_write

          reload if f.read.chomp == 'Recover'
        end
      end

    end
  end
end
