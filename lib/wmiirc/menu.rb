require 'shellwords'

module Wmiirc

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

end
