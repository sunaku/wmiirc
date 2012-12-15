require 'shellwords'

module Wmiirc

  HISTORY_DIR = File.join(DIR, 'history')
  Dir.mkdir HISTORY_DIR unless Dir.exist? HISTORY_DIR

  ##
  # Shows a menu (where the user must press keys on their keyboard to
  # make a choice) with the given items and returns the chosen item.
  #
  # @return nil if nothing was chosen.
  #
  # @param [Array] choices
  #   List of choices to display in the menu.
  #
  # @param [String] prompt
  #   Instruction on what the user should enter or choose.
  #
  # @param [String] history_name
  #   Basename of the file in which the user's
  #   choices will be stored: the history file.
  #
  # @param [Integer] history_size
  #   Number of items to keep in the history file.
  #
  def key_menu choices, prompt, history_name, history_size=200
    command = ['wimenu']
    command.push '-p', prompt.to_s if prompt

    if history_name
      history_file = File.join(HISTORY_DIR, history_name.to_s)
      command.push '-h', history_file, '-n', history_size.to_s

      # show history before actual choices
      if File.exist? history_file
        history = File.readlines(history_file).map(&:chomp)
        choices = (history & choices).reverse.concat(choices).uniq
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
  # @return (see #key_menu)
  #
  # @param choices (see #key_menu)
  #
  # @param initial
  #   The choice that should be initially selected.
  #
  #   If this choice is not included in the list
  #   of choices, then this item will be made
  #   into a makeshift title-bar for the menu.
  #
  def click_menu choices, initial=nil
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
  # Shows a {#key_menu} containing
  # all currently available clients
  # and returns the chosen client.
  #
  def client_menu *key_menu_args
    clients = Rumai.clients

    choices = clients.map do |c|
      "#{c[:label].read.downcase} @#{c[:tags].read}"
    end

    if index = index_menu(choices, *key_menu_args)
      clients[index]
    end
  end

  ##
  # Shows a {#key_menu} containing
  # the given choices and returns
  # the index of the chosen item.
  #
  def index_menu choices, *key_menu_args
    choices = choices.each_with_index.map {|c,i| "#{c}\t#{i}" }
    if target = key_menu(choices, *key_menu_args)
      target[/\d+\z/].to_i
    end
  end

end
