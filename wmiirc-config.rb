# Ruby-based configuration file for wmii.
=begin
  Copyright 2006, 2007 Suraj N. Kurapati

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation; either version 2
  of the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
=end

$: << File.join(File.dirname(__FILE__), 'wmii-irb')
require 'wm'
include Wmii

require 'find'


############################################################################
# CONFIGURATION VARIABLES
############################################################################

MODKEY            = 'Mod1'
UP_KEY            = 't'
DOWN_KEY          = 'n'
LEFT_KEY          = 'h'
RIGHT_KEY         = 's'

MOD_PREFIX        = MODKEY + '-Control-'
MOD_FOCUS         = MOD_PREFIX
MOD_SEND          = MOD_PREFIX + 'm,'
MOD_SWAP          = MOD_PREFIX + 'w,'
MOD_ARRANGE       = MOD_PREFIX + 'z,'
MOD_GROUP         = MOD_PREFIX + 'g,'
MOD_MENU          = MOD_PREFIX
MOD_EXEC          = MOD_PREFIX

PRIMARY_CLICK     = 1
MIDDLE_CLICK      = 2
SECONDARY_CLICK   = 3

# Tag used for wmii-2 style client detaching.
DETACHED_TAG      = '|'

# Colors tuples are "<text> <background> <border>"
WMII_NORMCOLORS   = '#e0e0e0 #0a0a0a #202020'
WMII_FOCUSCOLORS  = '#ffffff #285577 #4c7899'
WMII_BACKGROUND   = '#333333'
WMII_FONT         = '-*-fixed-medium-r-normal-*-18-*-*-*-*-*-*-*'

WMII_MENU         = "dmenu -b -fn #{WMII_FONT.inspect} #{
                      %w[-nf -nb -sf -sb].zip(
                        WMII_NORMCOLORS.split[0,2] +
                        WMII_FOCUSCOLORS.split[0,2]
                      ).flatten!.map! {|s| s.inspect}.join(' ')
                    }"
WMII_TERM         = 'gnome-terminal'

# export WMII_* constants as environment variables
  k = self.class
  k.constants.grep(/^WMII_/).each do |c|
    ENV[c] = k.const_get c
  end


############################################################################
# WM CONFIGURATION
############################################################################

fs.ctl = <<EOF
font #{WMII_FONT}
focuscolors #{WMII_FOCUSCOLORS}
normcolors #{WMII_NORMCOLORS}
grabmod #{MODKEY}
border 1
EOF


############################################################################
# COLUMN RULES
############################################################################

fs.colrules = <<EOF
/.*/ -> 58+42
EOF


############################################################################
# TAGGING RULES
############################################################################

fs.tagrules = <<EOF
/Buddy List.*/ -> chat
/XChat.*/ -> chat
/.*thunderbird.*/ -> mail
/xconsole.*/ -> ~
/alsamixer.*/ -> ~
/QEMU.*/ -> ~
/XMMS.*/ -> ~
/Gimp.*/ -> gimp
/MPlayer.*/ -> ~
/.*/ -> !
/.*/ -> 1
EOF


############################################################################
# FUNCTIONS
############################################################################

# Shows a menu with the given items and returns the chosen item.
# If nothing was chosen, then *nil* is returned.
def show_menu aChoices, aPrompt = nil
  cmd = WMII_MENU
  cmd += ' -p ' << aPrompt.to_s.inspect if aPrompt

  IO.popen cmd, 'r+' do |menu|
    menu.puts aChoices
    menu.close_write

    choice = menu.read
    choice unless choice.empty?
  end
end

# Returns the names of programs present in the given directories.
def find_programs *aPaths
  aPaths.flatten!
  aPaths.map! {|p| File.expand_path p}
  list = []

  Find.find(*aPaths) do |f|
    if File.file? f and File.executable? f
      list << File.basename(f)
    end
  end

  list.uniq!
  list.sort!
  list
end


############################################################################
# INTERNAL ACTIONS
############################################################################

ACTIONS = {
  :rehash => lambda do
    @programMenu = find_programs(ENV['PATH'].squeeze(':').split(':'))
    @actionMenu = find_programs(File.dirname(__FILE__))
  end,

  :quit => lambda do
    Wmii.fs.ctl = 'quit'
  end,

  :status => lambda do
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
            WMII_NORMCOLORS,
            Time.now,
            cpuLoad,
            diskSpace,
          ].join(' | ')

          sleep 1
        end
      end
    end
  end,
}

ACTIONS[:rehash].call
ACTIONS[:status].call


############################################################################
# KEY BINDINGS
############################################################################

SHORTCUTS = {

  ##########################################################################
  ## focusing / showing
  ##########################################################################

  # focus client at left
  MOD_FOCUS + LEFT_KEY => lambda do
    current_view.ctl = 'select left'
  end,

  # focus client at right
  MOD_FOCUS + RIGHT_KEY => lambda do
    current_view.ctl = 'select right'
  end,

  # focus client below
  MOD_FOCUS + DOWN_KEY => lambda do
    current_view.ctl = 'select down'
  end,

  # focus client above
  MOD_FOCUS + UP_KEY => lambda do
    current_view.ctl = 'select up'
  end,

  # toggle focus between floating area and the columns
  MOD_FOCUS + 'space' => lambda do
    current_view.ctl = 'select toggle'
  end,

  # apply equal-spacing layout to current column
  MOD_ARRANGE + 'w' => lambda do
    if a = current_area
      a.layout = :default
    end
  end,

  # apply equal-spacing layout to all columns
  MOD_ARRANGE + 'Shift-w' => lambda do
    current_view.columns.each do |a|
      a.layout = :default
    end
  end,

  # apply stacked layout to currently focused column
  MOD_ARRANGE + 'v' => lambda do
    if a = current_area
      a.layout = :stack
    end
  end,

  # apply stacked layout to all columns in current view
  MOD_ARRANGE + 'Shift-v' => lambda do
    current_view.columns.each do |a|
      a.layout = :stack
    end
  end,

  # apply maximized layout to currently focused column
  MOD_ARRANGE + 'm' => lambda do
    if a = current_area
      a.layout = :max
    end
  end,

  # apply maximized layout to all columns in current view
  MOD_ARRANGE + 'Shift-m' => lambda do
    current_view.columns.each do |a|
      a.layout = :max
    end
  end,

  # focus the previous view
  MOD_FOCUS + 'comma' => lambda do
    if v = prev_view
      v.focus
    end
  end,

  # focus the next view
  MOD_FOCUS + 'period' => lambda do
    if v = next_view
      v.focus
    end
  end,


  ##########################################################################
  ## interactive menu
  ##########################################################################

  # launch an internal action by choosing from a menu
  MOD_MENU + 'i' => lambda do
    if choice = show_menu(@actionMenu + ACTIONS.keys, 'run action:')
      if action = ACTIONS[choice.to_sym]
        action.call
      else
        system choice << '&'
      end
    end
  end,

  # launch an external program by choosing from a menu
  MOD_MENU + 'e' => lambda do
    if choice = show_menu(@programMenu, 'run program:')
      system choice << '&'
    end
  end,

  # focus any view by choosing from a menu
  MOD_MENU + 'u' => lambda do
    if choice = show_menu(tags, 'show view:')
      focus_view choice
    end
  end,

  # focus any client by choosing from a menu
  MOD_MENU + 'a' => lambda do
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
  end,


  ##########################################################################
  ## sending / moving
  ##########################################################################

  MOD_SEND + LEFT_KEY => lambda do
    grouped_clients.each do |c|
      c.send :left
    end
  end,

  MOD_SEND + RIGHT_KEY => lambda do
    grouped_clients.each do |c|
      c.send :right
    end
  end,

  MOD_SEND + DOWN_KEY => lambda do
    grouped_clients.each do |c|
      c.send :down
    end
  end,

  MOD_SEND + UP_KEY => lambda do
    grouped_clients.each do |c|
      c.send :up
    end
  end,

  MOD_SEND + 'space' => lambda do
    grouped_clients.each do |c|
      c.send :toggle
    end
  end,

  MOD_SEND + 'Delete' => lambda do
    grouped_clients.each do |c|
      c.ctl = 'kill'
    end
  end,

  # swap the currently focused client with the one to its left
  MOD_SWAP + LEFT_KEY => lambda do
    current_client.swap :left
  end,

  # swap the currently focused client with the one to its right
  MOD_SWAP + RIGHT_KEY => lambda do
    current_client.swap :right
  end,

  # swap the currently focused client with the one below it
  MOD_SWAP + DOWN_KEY => lambda do
    current_client.swap :down
  end,

  # swap the currently focused client with the one above it
  MOD_SWAP + UP_KEY => lambda do
    current_client.swap :up
  end,

  # Changes the tag (according to a menu choice) of each grouped client and
  # returns the chosen tag. The +tag -tag idea is from Jonas Pfenniger:
  # <http://zimbatm.oree.ch/articles/2006/06/15/wmii-3-and-ruby>
  MOD_SEND + 't' => lambda do
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
  end,


  ##########################################################################
  ## visual arrangement
  ##########################################################################

  MOD_ARRANGE + 't' => lambda do
    current_view.arrange_as_larswm
  end,

  MOD_ARRANGE + 'g' => lambda do
    current_view.arrange_in_grid
  end,

  MOD_ARRANGE + 'd' => lambda do
    current_view.arrange_in_diamond
  end,


  ##########################################################################
  ## client grouping
  ##########################################################################

  # include/exclude the currently focused client from the grouping
  MOD_GROUP + 'g' => lambda do
    current_client.toggle_grouping
  end,

  # include all clients in the currently focused view in the grouping
  MOD_GROUP + 'v' => lambda do
    current_view.group
  end,

  # exclude all clients in the currently focused view from the grouping
  MOD_GROUP + 'Shift-v' => lambda do
    current_view.ungroup
  end,

  # include all clients in the currently focused column in the grouping
  MOD_GROUP + 'c' => lambda do
    current_area.group
  end,

  # exclude all clients in the currently focused column from the grouping
  MOD_GROUP + 'Shift-c' => lambda do
    current_area.ungroup
  end,

  # invert the grouping in the currently focused view
  MOD_GROUP + 'i' => lambda do
    current_view.toggle_grouping
  end,

  # exclude all clients everywhere from the grouping
  MOD_GROUP + 'n' => lambda do
    ungroup_all
  end,


  ##########################################################################
  ## external programs
  ##########################################################################

  MOD_EXEC + 'x' => lambda do
    system WMII_TERM + ' &'
  end,

  MOD_EXEC + 'k' => lambda do
    system 'firefox &'
  end,

  MOD_EXEC + 'j' => lambda do
    system 'nautilus --no-desktop &'
  end,


  ##########################################################################
  ## detaching (wmii-2 style)
  ##########################################################################

  # Detach the current grouping to a separate tag.
  MOD_PREFIX + 'd' => lambda do
    grouped_clients.each do |c|
      c.tags = DETACHED_TAG
    end
  end,

  # Attach the most recently detached client.
  MOD_PREFIX + 'Shift-d' => lambda do
    v = View.new DETACHED_TAG

    if v.exist? and c = v.clients.last
      c.tags = current_tag
    end
  end,


  ##########################################################################
  ## zooming / sizing
  ##########################################################################

  # Sends grouped clients to temporary view.
  MOD_PREFIX + 'b' => lambda do
    src = current_tag
    dst = src + '~' + Time.now.to_i.to_s

    grouped_clients.each do |c|
      c.tag dst
    end

    v = View.new dst
    v.focus
    v.arrange_in_grid
  end,

  # Sends grouped clients back to their original view.
  MOD_PREFIX + 'Shift-b' => lambda do
    t = current_tag

    if t =~ /~\d+$/
      grouped_clients.each do |c|
        c.with_tags do
          delete t
          push $` if empty?
        end
      end

      focus_view $`
    end
  end,
}

  ##########################################################################
  ## number keys
  ##########################################################################

  10.times do |i|
    # focus {i}'th view
    SHORTCUTS[MOD_FOCUS + i.to_s] = lambda do
      focus_view tags[i - 1] || i
    end

    # send current grouping to {i}'th view
    SHORTCUTS[MOD_SEND + i.to_s] = lambda do
      grouped_clients.each do |c|
        c.tags = tags[i - 1] || i
      end
    end

    # apply grid layout with {i} clients per column
    SHORTCUTS[MOD_ARRANGE + i.to_s] = lambda do
      current_view.arrange_in_grid i
    end
  end

  ##########################################################################
  ## alphabet keys
  ##########################################################################

  # focus the view whose name begins with an alphabet key
  ('a'..'z').each do |key|
    SHORTCUTS[MOD_FOCUS + 'v,' + key] = lambda do
      if t = tags.grep(/^#{key}/i).first
        focus_view t
      end
    end
  end

fs.keys = SHORTCUTS.keys.join("\n")


############################################################################
# START UP
############################################################################

system 'xsetroot -solid $WMII_BACKGROUND &'

# initialize the tag bar
  fs.lbar.clear

  sel = current_tag
  tags.each do |tag|
    bar = fs.lbar[tag]
    bar.create

    color = if tag == sel
      WMII_FOCUSCOLORS
    else
      WMII_NORMCOLORS
    end

    bar.write "#{color} #{tag}"
  end


############################################################################
# EVENT LOOP
############################################################################

fs.event.open do |bus|
  loop do
    bus.read.split("\n").each do |event|
      type, parms = event.split(' ', 2)

      case type.to_sym
        when :Start
          exit if parms == 'wmiirc'

        when :CreateTag
          bar = fs.lbar[parms]
          bar.create
          bar.write "#{WMII_NORMCOLORS} #{parms}"

        when :DestroyTag
          fs.lbar[parms].remove

        when :FocusTag
          fs.lbar[parms] << "#{WMII_FOCUSCOLORS} #{parms}"

        when :UnfocusTag
          fs.lbar[parms] << "#{WMII_NORMCOLORS} #{parms}"

        when :UrgentTag
          fs.lbar[parms] << "*#{parms}"

        when :NotUrgentTag
          fs.lbar[parms] << parms

        when :LeftBarClick
          button, viewId = parms.split

          case button.to_i
            when PRIMARY_CLICK
              focus_view viewId

            when MIDDLE_CLICK
              grouped_clients.each do |c|
                c.tag viewId
              end

            when SECONDARY_CLICK
              grouped_clients.each do |c|
                c.untag viewId
              end
          end

        when :ClientClick
          clientId, button = parms.split

          if button.to_i == SECONDARY_CLICK
            Client.toggle_grouping clientId
          end

        when :Key
          SHORTCUTS[parms].call
      end
    end
  end
end
