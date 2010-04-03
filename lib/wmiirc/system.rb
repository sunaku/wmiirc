require 'pathname'

module Wmiirc

  ##
  # Launches the given command in the background.
  #
  # ==== Parameters
  #
  # [command]
  #   The name or path to the program you want
  #   to launch.  This can be a self-contained
  #   shell command if no arguments are given.
  #
  # [arguments_then_wihack_options]
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
  #   launch 'xmessage', 'hello world', Time.now.to_s, :type => 'DIALOG'
  #
  def launch command, *arguments_then_wihack_options
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

    system "#{command} &"
  end

  ##
  # Shows a dialog box containing the given message.
  #
  # This is a "fire and forget" operation.  The result of
  # the launched dialog box is NOT returned by this method!
  #
  # ==== Parameters
  #
  # [message]
  #   The message to be displayed.
  #
  # [arguments]
  #   Additional command-line arguments for `xmessage`.
  #
  def dialog message, *arguments
    launch 'xmessage', '-nearmouse', *arguments, message, :type => 'DIALOG'
  end

  ##
  # Returns the basenames of executable files found in the given directories.
  #
  def find_programs *directories
    directories.flatten.
    map {|d| Pathname.new(d).expand_path.children rescue [] }.flatten.
    map {|f| f.basename.to_s if f.file? and f.executable? }.compact.uniq.sort
  end

end
