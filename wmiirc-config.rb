# Ruby-based configuration file for wmii.
#--
# Copyright 2006-2007 Suraj N. Kurapati
# See the file named LICENSE for details.


# load the wmii-irb library
$: << File.join(File.dirname(__FILE__), 'wmii-irb')
require 'wm'
include Wmii


################################################################################
# Miniature DSL to ease configuration.
# Adapted from Kris Maglione and borior.
################################################################################

class HandlerHash < Hash
  def handle aKey, *aArgs, &aBlock
    if block_given?
      self[aKey] = aBlock
    elsif key? aKey
      self[aKey].call(*aArgs)
    end
  end
end

EVENTS    = HandlerHash.new
ACTIONS   = HandlerHash.new
SHORTCUTS = HandlerHash.new

def event *a, &b
  EVENTS.handle(*a, &b)
end

def action *a, &b
  ACTIONS.handle(*a, &b)
end

def shortcut *a, &b
  SHORTCUTS.handle(*a, &b)
end


################################################################################
# Utility functions
################################################################################

# Shows a menu with the given items and returns the chosen item.
# If nothing was chosen, then *nil* is returned.
def show_menu aChoices, aPrompt = nil
  cmd = "dmenu -b -fn #{WMII_FONT.inspect} " <<
        %w[-nf -nb -sf -sb].zip(
          Color::NORMAL.split[0,2] + Color::FOCUSED.split[0,2]
        ).flatten!.map! {|s| s.inspect}.join(' ')

  cmd << " -p #{aPrompt.to_s.inspect}" if aPrompt

  IO.popen cmd, 'r+' do |menu|
    menu.puts aChoices
    menu.close_write

    choice = menu.read
    choice unless choice.empty?
  end
end


require 'find'

# Returns the names of programs present in the given directories.
def find_programs aDirs
  aDirs = aDirs.map {|p| File.expand_path p}
  names = []

  Find.find(*aDirs) do |f|
    if File.file? f and File.executable? f
      names << File.basename(f)
    end
  end

  names.uniq!
  names.sort!
  names
end


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
  FIRST_CLICK  = 1
  MIDDLE_CLICK = 2
  SECOND_CLICK = 3
  SCROLL_UP    = 4
  SCROLL_DOWN  = 5
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

  event :Start do |arg|
    exit if arg == 'wmiirc'
  end

  event :Key do |*args|
    shortcut(*args)
  end

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
    when Mouse::FIRST_CLICK
      focus_view viewId

    when Mouse::MIDDLE_CLICK
      # add the grouping onto the clicked view
      grouped_clients.each do |c|
        c.tag viewId
      end

    when Mouse::SECOND_CLICK
      # remove the grouping from the clicked view
      grouped_clients.each do |c|
        c.untag viewId
      end
    end
  end

  event :ClientClick do |clientId, button|
    case button.to_i
    when Mouse::SECOND_CLICK
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
    Wmii.fs.ctl = 'quit'
  end

  action :status do
    if defined? @status
      @status.kill
    end

    @status = Thread.new do
      bar = Wmii.fs.rbar.status
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


# Shortcuts

  # focusing / showing

    # focus client at left
    shortcut Key::FOCUS + Key::LEFT do
      current_view.ctl = 'select left'
    end

    # focus client at right
    shortcut Key::FOCUS + Key::RIGHT do
      current_view.ctl = 'select right'
    end

    # focus client below
    shortcut Key::FOCUS + Key::DOWN do
      current_view.ctl = 'select down'
    end

    # focus client above
    shortcut Key::FOCUS + Key::UP do
      current_view.ctl = 'select up'
    end

    # toggle focus between floating area and the columns
    shortcut Key::FOCUS + 'space' do
      current_view.ctl = 'select toggle'
    end

    # apply equal-spacing layout to current column
    shortcut Key::ARRANGE + 'w' do
      if a = current_area
        a.layout = :default
      end
    end

    # apply equal-spacing layout to all columns
    shortcut Key::ARRANGE + 'Shift-w' do
      current_view.columns.each do |a|
        a.layout = :default
      end
    end

    # apply stacked layout to currently focused column
    shortcut Key::ARRANGE + 'v' do
      if a = current_area
        a.layout = :stack
      end
    end

    # apply stacked layout to all columns in current view
    shortcut Key::ARRANGE + 'Shift-v' do
      current_view.columns.each do |a|
        a.layout = :stack
      end
    end

    # apply maximized layout to currently focused column
    shortcut Key::ARRANGE + 'm' do
      if a = current_area
        a.layout = :max
      end
    end

    # apply maximized layout to all columns in current view
    shortcut Key::ARRANGE + 'Shift-m' do
      current_view.columns.each do |a|
        a.layout = :max
      end
    end

    # focus the previous view
    shortcut Key::FOCUS + 'comma' do
      if v = prev_view
        v.focus
      end
    end

    # focus the next view
    shortcut Key::FOCUS + 'period' do
      if v = next_view
        v.focus
      end
    end


  # sending / moving

    shortcut Key::SEND + Key::LEFT do
      grouped_clients.each do |c|
        c.send :left
      end
    end

    shortcut Key::SEND + Key::RIGHT do
      grouped_clients.each do |c|
        c.send :right
      end
    end

    shortcut Key::SEND + Key::DOWN do
      grouped_clients.each do |c|
        c.send :down
      end
    end

    shortcut Key::SEND + Key::UP do
      grouped_clients.each do |c|
        c.send :up
      end
    end

    # send all grouped clients from managed to floating area (or vice versa)
    shortcut Key::SEND + 'space' do
      grouped_clients.each do |c|
        c.send :toggle
      end
    end

    # close all grouped clients
    shortcut Key::SEND + 'Delete' do
      grouped_clients.each do |c|
        c.ctl = 'kill'
      end
    end

    # swap the currently focused client with the one to its left
    shortcut Key::SWAP + Key::LEFT do
      current_client.swap :left
    end

    # swap the currently focused client with the one to its right
    shortcut Key::SWAP + Key::RIGHT do
      current_client.swap :right
    end

    # swap the currently focused client with the one below it
    shortcut Key::SWAP + Key::DOWN do
      current_client.swap :down
    end

    # swap the currently focused client with the one above it
    shortcut Key::SWAP + Key::UP do
      current_client.swap :up
    end

    # Changes the tag (according to a menu choice) of each grouped client and
    # returns the chosen tag. The +tag -tag idea is from Jonas Pfenniger:
    # <http://zimbatm.oree.ch/articles/2006/06/15/wmii-3-and-ruby>
    shortcut Key::SEND + 't' do
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

        target
      end
    end


  # zooming / sizing

    # Sends grouped clients to temporary view.
    shortcut Key::PREFIX + 'b' do
      src = current_tag
      dst = src + '~'

      grouped_clients.each do |c|
        c.tag dst
      end

      v = View.new dst
      v.focus
      v.arrange_in_grid
    end

    # Sends grouped clients back to their original view.
    shortcut Key::PREFIX + 'Shift-b' do
      t = current_tag

      if t =~ /~$/
        grouped_clients.each do |c|
          c.with_tags do
            delete t
            push $` if empty?
          end
        end

      focus_view $`
      end
    end


  # client grouping

    # include/exclude the currently focused client from the grouping
    shortcut Key::GROUP + 'g' do
      current_client.toggle_grouping
    end

    # include all clients in the currently focused view in the grouping
    shortcut Key::GROUP + 'v' do
      current_view.group
    end

    # exclude all clients in the currently focused view from the grouping
    shortcut Key::GROUP + 'Shift-v' do
      current_view.ungroup
    end

    # include all clients in the currently focused column in the grouping
    shortcut Key::GROUP + 'c' do
      current_area.group
    end

    # exclude all clients in the currently focused column from the grouping
    shortcut Key::GROUP + 'Shift-c' do
      current_area.ungroup
    end

    # invert the grouping in the currently focused view
    shortcut Key::GROUP + 'i' do
      current_view.toggle_grouping
    end

    # exclude all clients everywhere from the grouping
    shortcut Key::GROUP + 'n' do
      ungroup_all
    end


  # visual arrangement

    shortcut Key::ARRANGE + 't' do
      current_view.arrange_as_larswm
    end

    shortcut Key::ARRANGE + 'g' do
      current_view.arrange_in_grid
    end

    shortcut Key::ARRANGE + 'd' do
      current_view.arrange_in_diamond
    end


  # interactive menu

    # launch an internal action by choosing from a menu
    shortcut Key::MENU + 'i' do
      if choice = show_menu(@actionMenu + ACTIONS.keys, 'run action:')
        unless action choice.to_sym
          system choice << '&'
        end
      end
    end

    # launch an external program by choosing from a menu
    shortcut Key::MENU + 'e' do
      if choice = show_menu(@programMenu, 'run program:')
        system choice << '&'
      end
    end

    # focus any view by choosing from a menu
    shortcut Key::MENU + 'u' do
      if choice = show_menu(tags, 'show view:')
        focus_view choice
      end
    end

    # focus any client by choosing from a menu
    shortcut Key::MENU + 'a' do
      list = Wmii.clients

      i = -1
      choices = list.map do |c|
        i += 1
        format "%d. [%s] %s", i, c[:tags].read, c[:props].read.downcase
      end

      if target = show_menu(choices, 'show client:')
        pos = target.scan(/\d+/).first.to_i
        list[pos].focus
      end
    end


  # external programs

    shortcut Key::EXECUTE + 'x' do
      system 'gnome-terminal &'
    end

    shortcut Key::EXECUTE + 'k' do
      system 'firefox &'
    end

    shortcut Key::EXECUTE + 'j' do
      system 'nautilus --no-desktop &'
    end


  # wmii-2 style client detaching

    DETACHED_TAG = '|'

    # Detach the current grouping from the current view.
    shortcut Key::PREFIX + 'd' do
      grouped_clients.each do |c|
        c.with_tags do
          c.tags = DETACHED_TAG
        end
      end
    end

    # Attach the most recently detached client onto the current view.
    shortcut Key::PREFIX + 'Shift-d' do
      v = View.new DETACHED_TAG

      if v.exist? and c = v.clients.last
        c.with_tags do
          c.tags = current_tag
        end
      end
    end


  # number keys

    10.times do |i|
      # focus the {i}'th view
      shortcut Key::FOCUS + i.to_s do
        focus_view tags[i - 1] || i
      end

      # send current grouping to {i}'th view
      shortcut Key::SEND, i.to_s do
        grouped_clients.each do |c|
          c.tags = tags[i - 1] || i
        end
      end

      # apply grid layout with {i} clients per column
      shortcut Key::ARRANGE, i.to_s do
        current_view.arrange_in_grid i
      end
    end


  # alphabet keys

    # focus the view whose name begins with an alphabet key
    ('a'..'z').each do |k|
      shortcut Key::VIEW + k do
        if t = tags.grep(/^#{k}/i).first
          focus_view t
        end
      end
    end


################################################################################
# START UP
################################################################################

system "xsetroot -solid #{Color::BACKGROUND.inspect} &"

# Misc Setup
action :status
action :rehash

# Tag Bar Setup
fs.lbar.clear

tags.each do |tag|
  color = (tag == current_tag) ? Color::FOCUSED : Color::NORMAL

  bar = fs.lbar[tag]
  bar.create
  bar.write "#{color} #{tag}"
end

# Keygrab Setup
fs.keys = SHORTCUTS.keys.join("\n")

# Event Loop
fs.event.open do |bus|
  loop do
    bus.read.split("\n").each do |event|
      type, parms = event.split(' ', 2)

      args = parms.split(' ') rescue []
      event type.to_sym, *args
    end
  end
end
