# Ruby-based configuration file for wmii.
#--
# Copyright 2006-2007 Suraj N. Kurapati
# See the file named LICENSE for details.

################################################################################
# GENERAL CONFIGURATION
################################################################################

module Key
  MOD       = 'Mod1'
  UP        = 't'
  DOWN      = 'n'
  LEFT      = 'h'
  RIGHT     = 's'

  PREFIX    = MOD + '-Control-'
  FOCUS     = PREFIX
  SEND      = PREFIX + 'm,'
  SWAP      = PREFIX + 'w,'
  ARRANGE   = PREFIX + 'z,'
  GROUP     = PREFIX + 'g,'
  VIEW      = PREFIX + 'v,'
  MENU      = PREFIX
  EXECUTE   = PREFIX
end

module Mouse
  PRIMARY     = 1
  MIDDLE      = 2
  SECONDARY   = 3
  SCROLL_UP   = 4
  SCROLL_DOWN = 5
end

module Color
  { # Color tuples are "<text> <background> <border>"
    :NORMCOLORS   => NORMAL     = '#e0e0e0 #0a0a0a #202020',
    :FOCUSCOLORS  => FOCUSED    = '#ffffff #285577 #4c7899',
    :BACKGROUND   => BACKGROUND = '#333333',
  }.each_pair do |k, v|
    ENV["WMII_#{k}"] = v
  end
end

WMII_FONT = '*-fixed-medium-r-normal-*-18-*-*-*-*-*-*-*'


################################################################################
# DETAILED CONFIGURATION
################################################################################

# WM Configuration
fs.ctl = <<EOF
grabmod #{Key::MOD}
border 2
font #{WMII_FONT}
focuscolors #{Color::FOCUSED}
normcolors #{Color::NORMAL}
EOF

# Column Rules
fs.colrules = <<EOF
/./ -> 60+40
EOF

# Tagging Rules
fs.tagrules = <<EOF
/Buddy List.*/ -> chat
/XChat.*/ -> chat
/.*thunderbird.*/ -> mail
/Gimp.*/ -> gimp
/xconsole.*/ -> ~
/alsamixer.*/ -> ~
/QEMU.*/ -> ~
/XMMS.*/ -> ~
/MPlayer.*/ -> ~
/.*/ -> !
/.*/ -> 1
EOF

# Events

  event :CreateTag do |tag|
    bar = fs.lbar[tag]
    bar.create
    bar.write "#{Color::NORMAL} #{tag}"
  end

  event :DestroyTag do |tag|
    fs.lbar[tag].remove
  end

  event :FocusTag do |tag|
    fs.lbar[tag] << "#{Color::FOCUSED} #{tag}"
  end

  event :UnfocusTag do |tag|
    fs.lbar[tag] << "#{Color::NORMAL} #{tag}"
  end

  event :UrgentTag do |tag|
    fs.lbar[tag] << "*#{tag}"
  end

  event :NotUrgentTag do |tag|
    fs.lbar[tag] << tag
  end

  event :LeftBarClick do |button, viewId|
    case button.to_i
    when Mouse::PRIMARY
      focus_view viewId

    when Mouse::MIDDLE
      # add the grouping onto the clicked view
      grouped_clients.each do |c|
        c.tag viewId
      end

    when Mouse::SECONDARY
      # remove the grouping from the clicked view
      grouped_clients.each do |c|
        c.untag viewId
      end
    end
  end

  event :ClientClick do |clientId, button|
    case button.to_i
    when Mouse::SECONDARY
      # toggle the clicked client's grouping
      Client.toggle_grouping clientId
    end
  end


# Actions

  action :rehash do
    @programMenu  = find_programs ENV['PATH'].squeeze(':').split(':')
    @actionMenu   = find_programs File.dirname(__FILE__)
  end

  action :quit do
    action :clear
    fs.ctl = 'quit'
  end

  action :clear do
    # firefox's restore session feature doesn't
    # work unless the whole process is killed.
    system 'killall firefox-bin'

    # gnome-panel refuses to die by other means
    system 'killall -s TERM gnome-panel'

    fs.event.open do |f|
      clients.each do |c|
        c.focus
        c.ctl = :kill

        # wait until the client is dead
        until f.read =~ /DestroyClient #{c.id}/
        end
      end
    end
  end

  action :status do
    if defined? @status
      @status.kill
    end

    @status = Thread.new do
      bar = fs.rbar.status
      bar.create unless bar.exist?

      loop do
        diskSpace = `df -h ~`.split[-3..-1].join(' ')
        cpuLoad = File.read('/proc/loadavg').split[0..2].join(' ')

        5.times do
          bar.write [
            Color::NORMAL,
            Time.now,
            cpuLoad,
            diskSpace,
          ].join(' | ')

          sleep 1
        end
      end
    end
  end


# Key bindings

  # focusing / showing

    # focus client at left
    key Key::FOCUS + Key::LEFT do
      current_view.ctl = 'select left'
    end

    # focus client at right
    key Key::FOCUS + Key::RIGHT do
      current_view.ctl = 'select right'
    end

    # focus client below
    key Key::FOCUS + Key::DOWN do
      current_view.ctl = 'select down'
    end

    # focus client above
    key Key::FOCUS + Key::UP do
      current_view.ctl = 'select up'
    end

    # toggle focus between floating area and the columns
    key Key::FOCUS + 'space' do
      current_view.ctl = 'select toggle'
    end

    # apply equal-spacing layout to current column
    key Key::ARRANGE + 'w' do
      current_area.layout = :default
    end

    # apply equal-spacing layout to all columns
    key Key::ARRANGE + 'Shift-w' do
      current_view.columns.each do |a|
        a.layout = :default
      end
    end

    # apply stacked layout to currently focused column
    key Key::ARRANGE + 'v' do
      current_area.layout = :stack
    end

    # apply stacked layout to all columns in current view
    key Key::ARRANGE + 'Shift-v' do
      current_view.columns.each do |a|
        a.layout = :stack
      end
    end

    # apply maximized layout to currently focused column
    key Key::ARRANGE + 'm' do
      current_area.layout = :max
    end

    # apply maximized layout to all columns in current view
    key Key::ARRANGE + 'Shift-m' do
      current_view.columns.each do |a|
        a.layout = :max
      end
    end

    # focus the previous view
    key Key::FOCUS + 'comma' do
      prev_view.focus
    end

    # focus the next view
    key Key::FOCUS + 'period' do
      next_view.focus
    end


  # sending / moving

    key Key::SEND + Key::LEFT do
      grouped_clients.each do |c|
        c.send :left
      end
    end

    key Key::SEND + Key::RIGHT do
      grouped_clients.each do |c|
        c.send :right
      end
    end

    key Key::SEND + Key::DOWN do
      grouped_clients.each do |c|
        c.send :down
      end
    end

    key Key::SEND + Key::UP do
      grouped_clients.each do |c|
        c.send :up
      end
    end

    # send all grouped clients from managed to floating area (or vice versa)
    key Key::SEND + 'space' do
      grouped_clients.each do |c|
        c.send :toggle
      end
    end

    # close all grouped clients
    key Key::SEND + 'Delete' do
      grouped_clients.each do |c|
        c.ctl = 'kill'
      end
    end

    # swap the currently focused client with the one to its left
    key Key::SWAP + Key::LEFT do
      current_client.swap :left
    end

    # swap the currently focused client with the one to its right
    key Key::SWAP + Key::RIGHT do
      current_client.swap :right
    end

    # swap the currently focused client with the one below it
    key Key::SWAP + Key::DOWN do
      current_client.swap :down
    end

    # swap the currently focused client with the one above it
    key Key::SWAP + Key::UP do
      current_client.swap :up
    end

    # Changes the tag (according to a menu choice) of each grouped client and
    # returns the chosen tag. The +tag -tag idea is from Jonas Pfenniger:
    # <http://zimbatm.oree.ch/articles/2006/06/15/wmii-3-and-ruby>
    key Key::SEND + 'v' do
      choices = tags.map {|t| [t, "+#{t}", "-#{t}"]}.flatten

      if target = show_menu(choices, 'tag as:')
        grouped_clients.each do |c|
          case target
          when /^\+/
            c.tag $'

          when /^\-/
            c.untag $'

          else
            c.tags = target
          end
        end
      end
    end


  # zooming / sizing

    # Sends grouped clients to temporary view.
    key Key::PREFIX + 'b' do
      src = current_tag
      dst = src + '~' + src.object_id.abs.to_s

      grouped_clients.each do |c|
        c.tag dst
      end

      v = View.new dst
      v.focus
      v.arrange_in_grid
    end

    # Sends grouped clients back to their original view.
    key Key::PREFIX + 'Shift-b' do
      src = current_tag

      if src =~ /~\d+$/
        dst = $`

        grouped_clients.each do |c|
          c.with_tags do
            delete src
            push dst if empty?
          end
        end

        focus_view dst
      end
    end


  # client grouping

    # include/exclude the currently focused client from the grouping
    key Key::GROUP + 'c' do
      current_client.toggle_grouping
    end

    # include all clients in the currently focused view into the grouping
    key Key::GROUP + 'v' do
      current_view.group
    end

    # exclude all clients in the currently focused view from the grouping
    key Key::GROUP + 'Shift-v' do
      current_view.ungroup
    end

    # include all clients in the currently focused area into the grouping
    key Key::GROUP + 'a' do
      current_area.group
    end

    # exclude all clients in the currently focused column from the grouping
    key Key::GROUP + 'Shift-a' do
      current_area.ungroup
    end

    # include all clients in the floating area into the grouping
    key Key::GROUP + 'f' do
      current_view.floating_area.group
    end

    # exclude all clients in the currently focused column from the grouping
    key Key::GROUP + 'Shift-f' do
      current_view.floating_area.ungroup
    end

    # include all clients in the managed areas into the grouping
    key Key::GROUP + 'm' do
      current_view.columns.each do |c|
        c.group
      end
    end

    # exclude all clients in the managed areas from the grouping
    key Key::GROUP + 'Shift-m' do
      current_view.columns.each do |c|
        c.ungroup
      end
    end

    # invert the grouping in the currently focused view
    key Key::GROUP + 'i' do
      current_view.toggle_grouping
    end

    # exclude all clients everywhere from the grouping
    key Key::GROUP + 'n' do
      ungroup_all
    end


  # visual arrangement

    key Key::ARRANGE + 't' do
      current_view.arrange_as_larswm
    end

    key Key::ARRANGE + 'g' do
      current_view.arrange_in_grid
    end

    key Key::ARRANGE + 'd' do
      current_view.arrange_in_diamond
    end


  # interactive menu

    # launch an internal action by choosing from a menu
    key Key::MENU + 'i' do
      if choice = show_menu(@actionMenu + ACTIONS.keys, 'run action:')
        unless action choice.to_sym
          system choice << '&'
        end
      end
    end

    # launch an external program by choosing from a menu
    key Key::MENU + 'e' do
      if choice = show_menu(@programMenu, 'run program:')
        system choice << '&'
      end
    end

    # focus any view by choosing from a menu
    key Key::MENU + 'u' do
      if choice = show_menu(tags, 'show view:')
        focus_view choice
      end
    end

    # focus any client by choosing from a menu
    key Key::MENU + 'a' do
      choices = []
      clients.each_with_index do |c, i|
        choices << "%d. [%s] %s" % [i, c[:tags].read, c[:props].read.downcase]
      end

      if target = show_menu(choices, 'show client:')
        i = target.scan(/\d+/).first.to_i
        clients[i].focus
      end
    end


  # external programs

    key Key::EXECUTE + 'x' do
      system 'gnome-terminal &'
    end

    key Key::EXECUTE + 'k' do
      system 'firefox &'
    end

    key Key::EXECUTE + 'j' do
      system 'nautilus --no-desktop &'
    end


  # wmii-2 style client detaching

    DETACHED_TAG = '|'

    # Detach the current grouping from the current view.
    key Key::PREFIX + 'd' do
      grouped_clients.each do |c|
        c.with_tags do
          delete current_tag
          push DETACHED_TAG
        end
      end
    end

    # Attach the most recently detached client onto the current view.
    key Key::PREFIX + 'Shift-d' do
      v = View.new DETACHED_TAG

      if v.exist? and c = v.clients.last
        c.with_tags do
          delete DETACHED_TAG
          push current_tag
        end
      end
    end


  # number keys

    10.times do |i|
      # focus the {i}'th view
      key Key::FOCUS + i.to_s do
        focus_view tags[i - 1] || i
      end

      # send current grouping to {i}'th view
      key Key::SEND + i.to_s do
        grouped_clients.each do |c|
          c.tags = tags[i - 1] || i
        end
      end

      # swap current client with the primary client in {i}'th column
      key Key::SWAP + i.to_s do
        current_view.ctl = "swap sel #{i}"
      end

      # apply grid layout with {i} clients per column
      key Key::ARRANGE + i.to_s do
        current_view.arrange_in_grid i
      end
    end


  # alphabet keys

    # focus the view whose name begins with an alphabet key
    ('a'..'z').each do |k|
      key Key::VIEW + k do
        if t = tags.grep(/^#{k}/i).first
          focus_view t
        end
      end
    end


# Misc Setup
system "xsetroot -solid #{Color::BACKGROUND.inspect} &"
action :status
action :rehash
