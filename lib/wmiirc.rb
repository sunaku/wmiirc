#--
# Copyright protects this work.
# See LICENSE file for details.
#++

require 'logger'
require 'shellwords'
require 'pathname'

require 'rubygems'
gem 'rumai', '>= 3.2.0', '< 4'
require 'rumai'

module Rumai
  # TODO: move this upstream
  module_function :fs
end

module Wmiirc

  # path to user's wmii configuration directory
  DIR = File.dirname(File.dirname(__FILE__))

  # keep a log file to aid the user in debugging
  LOG = Logger.new(File.join(DIR, 'wmiirc.log'), 5)

  # insulation for code in user's configuration
  class Sandbox
    include Rumai
    include Wmiirc
    alias eval instance_eval
  end

  SANDBOX = Sandbox.new

  # make instance methods into module functions
  extend self

  require 'wmiirc/handler'

  ##
  # Shows a menu (where the user must press keys on their keyboard to
  # make a choice) with the given items and returns the chosen item.
  #
  # If nothing was chosen, then nil is returned.
  #
  # ==== Parameters
  #
  # [prompt]
  #   Instruction on what the user should enter or choose.
  #
  def key_menu choices, prompt = nil
    words = ['dmenu', '-fn', CONFIG['display']['font']]

    # show menu at the same location as the status bar
    words << '-b' if CONFIG['display']['bar'] == 'bottom'

    words.concat %w[-nf -nb -sf -sb].zip(
      [
        CONFIG['display']['color']['normal'],
        CONFIG['display']['color']['focus'],

      ].map {|c| c.to_s.split[0,2] }.flatten

    ).flatten

    words.push '-p', prompt if prompt

    command = words.shelljoin
    IO.popen(command, 'r+') do |menu|
      menu.puts choices
      menu.close_write

      choice = menu.read
      choice unless choice.empty?
    end
  end

  ##
  # Shows a menu (where the user must click a menu
  # item using their mouse to make a choice) with
  # the given items and returns the chosen item.
  #
  # If nothing was chosen, then nil is returned.
  #
  # ==== Parameters
  #
  # [choices]
  #   List of choices to display in the menu.
  #
  # [initial]
  #   The choice that should be initially selected.
  #
  #   If this choice is not included in the list
  #   of choices, then this item will be made
  #   into a makeshift title-bar for the menu.
  #
  def click_menu choices, initial = nil
    words = ['wmii9menu']

    if initial
      words << '-i'

      unless choices.include? initial
        initial = "<<#{initial}>>:"
        words << initial
      end

      words << initial
    end

    words.concat choices
    command = words.shelljoin

    choice = `#{command}`.chomp
    choice unless choice.empty?
  end

  ##
  # Shows a key_menu() containing the given
  # clients and returns the chosen client.
  #
  # If nothing was chosen, then nil is returned.
  #
  # ==== Parameters
  #
  # [prompt]
  #   Instruction on what the user should enter or choose.
  #
  # [clients]
  #   List of clients to present as choices to the user.
  #
  #   If this parameter is not specified,
  #   its default value will be a list of
  #   all currently available clients.
  #
  def client_menu prompt = nil, clients = Rumai.clients
    choices = clients.map do |c|
      "[#{c[:tags].read}] #{c[:label].read.downcase}"
    end

    if index = index_menu(choices, prompt)
      clients[index]
    end
  end

  ##
  # Shows a key_menu() containing the given choices (automatically
  # prefixed with indices) and returns the index of the chosen item.
  #
  # If nothing was chosen, then nil is returned.
  #
  # ==== Parameters
  #
  # [prompt]
  #   Instruction on what the user should enter or choose.
  #
  # [choices]
  #   List of choices to present to the user.
  #
  def index_menu choices, prompt = nil
    indices = []
    choices.each_with_index do |c, i|
      # use natural 1..N numbering
      indices << "#{i+1}. #{c}"
    end

    if target = key_menu(indices, prompt)
      # use array 0..N-1 numbering
      index = target[/^\d+/].to_i-1

      # ignore out of bounds index
      # (possibly entered by user)
      if index >= 0 && index < choices.length
        index
      end
    end
  end

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
