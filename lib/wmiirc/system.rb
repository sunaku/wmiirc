#--
# Copyright protects this work.
# See LICENSE file for details.
#++

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
  # [arguments]
  #   Command-line arguments for the command being launched.
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
  def launch command, *arguments
    unless arguments.empty?
      command = [command, *arguments].shelljoin
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
    # show dialog in floating area
    Rumai.curr_view.floating_area.focus

    arguments << message
    launch 'xmessage', '-nearmouse', *arguments
  end

  ##
  # Returns the basenames of executable files present in the given directories.
  #
  def find_programs *dirs
    dirs.flatten.
    map {|d| Pathname.new(d).expand_path.children rescue [] }.flatten.
    map {|f| f.basename.to_s if f.file? and f.executable? }.compact.uniq.sort
  end

end
