require 'shellwords'

module Wmiirc

  HISTORY_DIR = File.join(DIR, 'history')

  require 'fileutils'
  FileUtils.mkdir_p(HISTORY_DIR)

  ##
  # Shows a menu (where the user must press keys on their keyboard to
  # make a choice) with the given items and returns the chosen item.
  #
  # If nothing was chosen, then nil is returned.
  #
  # ==== Parameters
  #
  # [choices]
  #   List of choices to display in the menu.
  #
  # [prompt]
  #   Instruction on what the user should enter or choose.
  #
  # [history_name]
  #   Basename of the file in which the user's
  #   choices will be stored: the history file.
  #
  # [history_size]
  #   Number of items to keep in the history file.
  #
  def key_menu choices, prompt = nil, history_name = nil, history_size = 200
    command = ['wimenu']
    command.push '-p', prompt.to_s if prompt

    if history_name
      history_file = File.join(HISTORY_DIR, history_name.to_s)
      command.push '-h', history_file, '-n', history_size.to_s

      # show history before actual choices
      if File.exist? history_file
        history = File.read(history_file).split(/\n/)
        choices = ((history & choices).reverse + choices).uniq
      end
    end

    IO.popen(command.shelljoin, 'r+') do |menu|
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
    command = ['wmii9menu']

    if initial
      command << '-i'

      unless choices.include? initial
        initial = "<<#{initial}>>:"
        command << initial
      end

      command << initial
    end

    command.concat choices

    choice = `#{command.shelljoin}`.chomp
    choice unless choice.empty?
  end

  ##
  # Shows a key_menu() containing
  # all currently available clients
  # and returns the chosen client.
  #
  # If nothing was chosen, then nil is returned.
  #
  # ==== Parameters
  #
  # [prompt]
  #   Instruction on what the user should enter or choose.
  #
  def client_menu prompt = nil, *history_args
    clients = Rumai.clients

    choices = clients.map do |c|
      "+#{c[:tags].read}: #{c[:label].read.downcase}"
    end

    if index = index_menu(choices, prompt, *history_args)
      clients[index]
    end
  end

  ##
  # Shows a key_menu() containing
  # the given choices and returns
  # the index of the chosen item.
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
  def index_menu choices, prompt = nil, *history_args
    if target = key_menu(choices, prompt, *history_args)
      choices.index target
    end
  end

end
