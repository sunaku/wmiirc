module Wmiirc

  ##
  # Runs {#launch!} inside the present working directory of the
  # currently focused client or, if undeterminable, that of wmii.
  #
  def launch *args
    if label = curr_client.label.read rescue nil
      label.encode(Encoding::UTF_8, undef: :replace, replace: '').
      split(/[\s\[\]\{\}\(\)<>"':]+/).reverse_each do |word|
        if File.exist? path = File.expand_path(word)
          path = File.dirname(path) unless File.directory? path
          Dir.chdir(path){ launch! *args }
          return
        end
      end
    end

    launch! *args
  end

  ##
  # Launches the given command in the background.
  #
  # @param [String] command
  #   The name or path to the program you want
  #   to launch.  This can be a self-contained
  #   shell command if no arguments are given.
  #
  # @param arguments_then_wihack_options
  #   Command-line arguments for the command being launched,
  #   optionally followed by a Hash containing command-line
  #   option names and values for the `wihack` program.
  #
  # ==== Examples
  #
  # Launch a self-contained shell command (while making sure that
  # the arguments within the shell command are properly quoted):
  #
  #   launch "xmessage 'hello world' '#{Time.now}'"
  #
  # Launch a command with explicit arguments (while not
  # having to worry about shell-quoting those arguments):
  #
  #   launch 'xmessage', 'hello world', Time.now.to_s
  #
  # Launch a command on the floating layer (treating
  # it as a dialog box) using the `wihack` program:
  #
  #   launch 'xmessage', 'hello world', Time.now.to_s, type: 'DIALOG'
  #
  def launch! command, *arguments_then_wihack_options
    *arguments, wihack_options = arguments_then_wihack_options

    unless wihack_options.nil? or wihack_options.kind_of? Hash
      arguments.push wihack_options
      wihack_options = nil
    end

    unless arguments.empty?
      command = [command, *arguments].shelljoin
    end

    if wihack_options
      wihack_argv = wihack_options.map {|k,v| ["-#{k}", v] }.flatten
      command = "wihack #{wihack_argv.shelljoin} #{command}"
    end

    spawn command
  end

  ##
  # Shows a notification with the given title and message.
  #
  # This is a "fire and forget" operation.  The result of
  # the notification command is NOT returned by this method!
  #
  # @param title
  #   The title to be displayed.
  #
  # @param message
  #   The message to be displayed.
  #
  # @param icon
  #   The icon to be displayed.
  #
  # @param arguments
  #   Additional command-line arguments for `notify-send`.
  #
  def notify title, message, icon='dialog-information', *arguments
    Rumai.fs.event.write "Notice #{title}: #{message}\n"
    launch! 'notify-send', '-i', icon, title, message, *arguments
  end

  ##
  # Shows a dialog box containing the given message.
  #
  # This is a "fire and forget" operation.  The result of
  # the launched dialog box is NOT returned by this method!
  #
  # @param message
  #   The message to be displayed.
  #
  # @param arguments
  #   Additional command-line arguments for `xmessage`.
  #
  def dialog message, *arguments
    launch! 'xmessage', '-nearmouse', *arguments, message, type: 'DIALOG'
  end

end
