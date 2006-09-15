# Ruby-based configuration file for wmii.
=begin
  Copyright 2006 Suraj N. Kurapati

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

$: << File.dirname(__FILE__)
require 'fs'
require 'wm'
require 'rc'

FS = Wmii.fs


## WM startup

at_exit do LOG.info($$) {"exiting #{__FILE__}"} end
LOG.info($$) {"starting #{__FILE__}"}

FS.event = "Start #{__FILE__}\n"


## executable programs

PROGRAM_MENU = find_programs( ENV['PATH'].squeeze(':').split(':') )
ACTION_MENU = find_programs('~/dry/apps/wmii/etc/wmii-3', File.dirname(__FILE__))


## UI configuration

FS.def.border = 2

FS.def.font = ENV['WMII_FONT'] = '-misc-fixed-medium-r-normal--18-120-100-100-c-90-iso10646-1'
FS.def.selcolors = ENV['WMII_SELCOLORS'] = '#ffffff #285577 #4c7899'
FS.def.normcolors = ENV['WMII_NORMCOLORS'] = '#222222 #eeeeee #666666'

FS.def.colmode = :default
FS.def.colwidth = 0

system %{xsetroot -solid '#333333'}


## tagging rules

FS.def.rules = <<EOS
/jEdit.*/ -> code
/Buddy List.*/ -> chat
/XChat.*/ -> chat
/.*thunderbird.*/ -> mail
/Gimp.*/ -> gimp
/QEMU.*/ -> ~
/MPlayer.*/ -> ~
/xconsole.*/ -> ~
/alsamixer.*/ -> ~
/.*/ -> !
/.*/ -> 1
EOS


## key & shortcut configuration

MOD_KEY = 'Mod1'
UP_KEY = 't'
DOWN_KEY = 'n'
LEFT_KEY = 'h'
RIGHT_KEY = 's'

PRIMARY_CLICK = 1
MIDDLE_CLICK = 2
SECONDARY_CLICK = 3


# key sequence prefixed to all shortcuts
SEQ_PREFIX = "#{MOD_KEY}-Control-"

FOCUS_SEQ = SEQ_PREFIX
SEND_SEQ = "#{SEQ_PREFIX}m,"
SWAP_SEQ = "#{SEQ_PREFIX}w,"
LAYOUT_SEQ = "#{SEQ_PREFIX}z,"
GROUP_SEQ = "#{SEQ_PREFIX}g,"
MENU_SEQ = SEQ_PREFIX
PROGRAM_SEQ = SEQ_PREFIX


# Shortcut key sequences and their associated logic.
SHORTCUTS = {
  # focus previous view
  "#{FOCUS_SEQ}comma" => lambda do
    cycle_view :left
  end,

  # focus next view
  "#{FOCUS_SEQ}period" => lambda do
    cycle_view :right
  end,

  # focus previous area
  "#{FOCUS_SEQ}#{LEFT_KEY}" => lambda do
    Wmii.current_view.ctl = 'select prev'
  end,

  # focus next area
  "#{FOCUS_SEQ}#{RIGHT_KEY}" => lambda do
    Wmii.current_view.ctl = 'select next'
  end,

  # focus floating area
  "#{FOCUS_SEQ}space" => lambda do
    Wmii.current_view.ctl = 'select toggle'
  end,

  # focus previous client
  "#{FOCUS_SEQ}#{UP_KEY}" => lambda do
    Wmii.current_area.ctl = 'select prev'
  end,

  # focus next client
  "#{FOCUS_SEQ}#{DOWN_KEY}" => lambda do
    Wmii.current_area.ctl = 'select next'
  end,


  # apply equal spacing layout to currently focused column
  "#{LAYOUT_SEQ}w" => lambda do
    Wmii.current_area.mode = :default
  end,

  # apply equal spacing layout to all columns in current view
  "#{LAYOUT_SEQ}Shift-w" => lambda do
    Wmii.current_view.each_column do |a|
      a.mode = :default
    end
  end,

  # apply stacked layout to currently focused column
  "#{LAYOUT_SEQ}v" => lambda do
    Wmii.current_area.mode = :stack
  end,

  # apply stacked layout to all columns in current view
  "#{LAYOUT_SEQ}Shift-v" => lambda do
    Wmii.current_view.each_column do |a|
      a.mode = :stack
    end
  end,

  # apply maximized layout to currently focused column
  "#{LAYOUT_SEQ}m" => lambda do
    Wmii.current_area.mode = :max
  end,

  # apply maximized layout to all columns in current view
  "#{LAYOUT_SEQ}Shift-m" => lambda do
    Wmii.current_view.each_column do |a|
      a.mode = :max
    end
  end,

  # maximize the floating area's focused client
  "#{LAYOUT_SEQ}z" => lambda do
    Wmii.current_view[0].sel.geom = '0 0 east south'
  end,


  # apply tiling layout to the currently focused view
  "#{LAYOUT_SEQ}t" => lambda do
    Wmii.current_view.tile!
  end,

  # apply gridding layout to the currently focused view
  "#{LAYOUT_SEQ}g" => lambda do
    Wmii.current_view.grid!
  end,

  "#{LAYOUT_SEQ}d" => lambda do
    Wmii.current_view.diamond!
  end,


  # include/exclude the currently focused client from the selection
  "#{GROUP_SEQ}g" => lambda do
    Wmii.current_client.invert_selection!
  end,

  # include all clients in the currently focused view in the selection
  "#{GROUP_SEQ}a" => lambda do
    Wmii.current_view.select!
  end,

  # include all clients in the currently focused column in the selection
  "#{GROUP_SEQ}c" => lambda do
    Wmii.current_area.select!
  end,

  # exclude all clients in the currently focused column from the selection
  "#{GROUP_SEQ}Shift-c" => lambda do
    Wmii.current_area.unselect!
  end,

  # invert the selection in the currently focused view
  "#{GROUP_SEQ}i" => lambda do
    Wmii.current_view.invert_selection!
  end,

  # exclude all clients everywhere from the selection
  "#{GROUP_SEQ}n" => lambda do
    Wmii.select_none!
  end,


  # launch an internal action by choosing from a menu
  "#{MENU_SEQ}i" => lambda do
    action = show_menu(ACTION_MENU)
    system(action << '&') unless action.empty?
  end,

  # launch an external program by choosing from a menu
  "#{MENU_SEQ}e" => lambda do
    program = show_menu(PROGRAM_MENU)
    system(program << '&') unless program.empty?
  end,

  # focus any view by choosing from a menu
  "#{MENU_SEQ}Shift-v" => lambda do
    Wmii.focus_view(show_menu(Wmii.tags))
  end,

  "#{MENU_SEQ}a" => lambda do
    focus_client_from_menu
  end,


  "#{PROGRAM_SEQ}x" => lambda do
    system 'terminal &'
  end,

  "#{PROGRAM_SEQ}k" => lambda do
    system 'epiphany &'
  end,

  "#{PROGRAM_SEQ}j" => lambda do
    system 'nautilus --no-desktop &'
  end,


  "#{SEND_SEQ}#{LEFT_KEY}" => lambda do
    Wmii.selected_clients.each do |c|
      c.ctl = 'sendto prev'
    end
  end,

  "#{SEND_SEQ}#{RIGHT_KEY}" => lambda do
    Wmii.selected_clients.each do |c|
      c.ctl = 'sendto next'
    end
  end,

  "#{SEND_SEQ}space" => lambda do
    Wmii.selected_clients.each do |c|
      c.ctl = 'sendto toggle'
    end
  end,

  "#{SEND_SEQ}Delete" => lambda do
    # reverse b/c client indices are reassigned upon deletion.
    # ex: imagine you have these clients: [1, 2, 3]
    #     you delete the first client (index 1).
    #     now, wmii reorders the client indices: [1, 2]
    #     that is why we must go in reverse!
    Wmii.selected_clients.sort_by do |c|
      c.index.to_i
    end.reverse.each do |c|
      c.ctl = 'kill'
    end
  end,

  "#{SEND_SEQ}t" => lambda do
    change_tag_from_menu
  end,

  # remove currently focused view from current selection's tags
  "#{SEND_SEQ}Shift-minus" => lambda do
    curTag = Wmii.current_view.name

    Wmii.selected_clients.each do |c|
      c.untag! curTag
    end
  end,

  "#{SEQ_PREFIX}b" => lambda do
    toggle_temp_view
  end,

  # wmii-2 style detaching
  "#{SEQ_PREFIX}d" => lambda do
    detach_selection
  end,

  # wmii-2 style detaching
  "#{SEQ_PREFIX}Shift-d" => lambda do
    attach_last_client
  end,

  # toggle maximizing the currently focused client to full screen
  "#{SEND_SEQ}m" => lambda do
    SHORTCUTS["#{SEND_SEQ}space"].call
    SHORTCUTS["#{LAYOUT_SEQ}z"].call
  end,

  # swap the currently focused client with the one to its left
  "#{SWAP_SEQ}#{LEFT_KEY}" => lambda do
    Wmii.current_client.ctl = 'swap prev'
  end,

  # swap the currently focused client with the one to its right
  "#{SWAP_SEQ}#{RIGHT_KEY}" => lambda do
    Wmii.current_client.ctl = 'swap next'
  end,

  # swap the currently focused client with the one below it
  "#{SWAP_SEQ}#{DOWN_KEY}" => lambda do
    Wmii.current_client.ctl = 'swap down'
  end,

  # swap the currently focused client with the one above it
  "#{SWAP_SEQ}#{UP_KEY}" => lambda do
    Wmii.current_client.ctl = 'swap up'
  end,
}

10.times do |i|
  k = (i - 1) % 10	# associate '1' with the leftmost label, instead of '0'

  # focus _i_th view
  SHORTCUTS["#{FOCUS_SEQ}#{i}"] = lambda do
    Wmii.focus_view Wmii.tags[k] || i
  end

  # focus _i_th area
  SHORTCUTS["#{FOCUS_SEQ}Shift-#{i}"] = lambda do
    Wmii.focus_area i
  end

  # swap the currently focused client with the one in _i_th area
  SHORTCUTS["#{SWAP_SEQ}#{i}"] = lambda do
    Wmii.current_client.ctl = "swap #{i}"
  end

  # send selection to _i_th view
  SHORTCUTS["#{SEND_SEQ}#{i}"] = lambda do
    Wmii.selected_clients.each do |c|
      c.tags = Wmii.tags[k] || i
    end
  end

  # send selection to _i_th area
  SHORTCUTS["#{SEND_SEQ}Shift-#{i}"] = lambda do
    Wmii.current_view[i].insert! Wmii.selected_clients
  end

  # apply grid layout with _i_ clients per column
  SHORTCUTS["#{LAYOUT_SEQ}#{i}"] = lambda do
    Wmii.current_view.grid! i
  end

  # add _i_th view to current selection's tags
  SHORTCUTS["#{SEND_SEQ}equal,#{i}"] =
  SHORTCUTS["#{SEND_SEQ}Shift-equal,#{i}"] = lambda do
    Wmii.selected_clients.each do |c|
      c.tag! Wmii.tags[k] || i
    end
  end

  # remove _i_th view from current selection's tags
  SHORTCUTS["#{SEND_SEQ}minus,#{i}"] = lambda do
    Wmii.selected_clients.each do |c|
      c.untag! Wmii.tags[k] || i
    end
  end
end

# jump to view whose name begins with the pressed key
('a'..'z').each do |char|
  SHORTCUTS["#{MENU_SEQ}v,#{char}"] = lambda do
    choices = Wmii.tags
    choices.delete Wmii.current_view.name

    if view = choices.select {|t| t =~ /^#{char}/i}.first
      Wmii.focus_view view
    end
  end
end


FS.def.grabmod = MOD_KEY
FS.def.keys = SHORTCUTS.keys.join("\n")


## status bar

Thread.new do
  sb = Ixp::Node.new('/bar/status', true)
  sb.colors = ENV['WMII_NORMCOLORS']

  loop do
    diskSpace = `df -h ~`.split[-3..-1].join(' ')

    10.times do
      cpuLoad = File.read('/proc/loadavg').split[0..2].join(' ')

      sb.data = "#{Time.now.to_s} | #{cpuLoad} | #{diskSpace}"
      sleep 1
    end
  end
end


## WM event loop

begin
  # IXP::Client.new.open('/event') do |io| #io.read.chomp
  IO.popen 'wmiir read /event' do |io|
    while event = io.readline.chomp
      type, arg = event.split($;, 2)

      case type.to_sym
        when :Start
          if arg == __FILE__
            LOG.info($$) {"another config is starting"}
            exit
          end

        when :BarClick
          clickedView, clickedButton = arg.split

          case clickedButton.to_i
            when PRIMARY_CLICK
              Wmii.focus_view clickedView

            when MIDDLE_CLICK
              Wmii.selected_clients.each do |c|
                c.tag! clickedView
              end

            when SECONDARY_CLICK
              Wmii.selected_clients.each do |c|
                c.untag! clickedView
              end
          end

        when :ClientClick
          clickedClient, clickedButton = arg.split

          if clickedButton.to_i != PRIMARY_CLICK
            Wmii.get_client(clickedClient).invert_selection!
          end

        when :Key
          SHORTCUTS[arg].call
      end
    end
  end
rescue EOFError
  LOG.warn "wmii has been terminated"
  exit 1
end
