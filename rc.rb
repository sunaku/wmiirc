# Utility methods used by wmiirc.
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

require 'wm'
require 'find'

# Returns a list of program names available in the given paths.
def find_programs *aPaths
  aPaths.flatten!
  aPaths.map! {|p| File.expand_path p}
  list = []

  Find.find(*aPaths) do |f|
    if File.file?(f) && File.executable?(f)
      list << File.basename(f)
    end
  end

  list.uniq!
  list.sort!
  list
end

# Shows a menu with the given items and returns the chosen item. If nothing was chosen, *nil* is returned.
def show_menu *aChoices
  IO.popen('wmiimenu', 'r+') do |menu|
    menu.puts aChoices
    menu.close_write

    if (choice = menu.read).empty?
      nil
    else
      choice
    end
  end
end

# Focuses the client chosen from a menu.
def focus_client_from_menu
  choices = Wmii.clients.map do |c|
    format "%d. [%s] %s", c.index, c.tags, c.name.downcase
  end

  if target = show_menu(choices)
    Wmii.focus_client target.scan(/\d+/).first
  end
end

# Changes the tag, chosen from a menu, of each selected client and returns the chosen tag.
# The {+tag -tag idea}[http://zimbatm.oree.ch/articles/2006/06/15/wmii-3-and-ruby] is from Jonas Pfenniger.
def change_tag_from_menu
  choices = Wmii.tags.map {|t| [t, "+#{t}", "-#{t}"]}.flatten

  if target = show_menu(choices)
    Wmii.selected_clients.each do |c|
      case target
        when /^\+/
          c.tag! $'

        when /^\-/
          c.untag! $'

        else
          c.tags = target
      end
    end

    target
  end
end

# Send selected clients to temporary view or switch back again.
def toggle_temp_view
  curTag = Wmii.current_view.name

  if curTag =~ /~\d+$/
    Wmii.selected_clients.each do |c|
      c.with_tags do
        delete curTag
        push $` if empty?
      end
    end

    Wmii.focus_view $`

  else
    tmpTag = "#{curTag}~#{Time.now.to_i}"

    Wmii.selected_clients.each do |c|
      c.tag! tmpTag
    end

    Wmii.focus_view tmpTag
    Wmii.current_view.grid!
  end
end

# Puts focus on an adjacent view (:left or :right).
def cycle_view aTarget
  tags = Wmii.tags
  curTag = Wmii.current_view.name
  curIndex = tags.index(curTag)

  newIndex =
    case aTarget
      when :right
        curIndex + 1

      when :left
        curIndex - 1

      else
        return

    end % tags.length

  Wmii.focus_view tags[newIndex]
end

# Toggles maximization of the currently focused client.
def toggle_maximize
  src = Wmii.current_client
  srcId = src.index

  src.ctl = 'sendto toggle'
  dst = Wmii.current_view[0].sel

  if dst.index == srcId
    dst.geom = '0 0 east south'
  end
end

# Focuses the view whose name matches the given pattern. If more than one view matches, then they are cycled (adapted from Fredrik Ternerot).
def focus_view_matching aPattern
  choices = Wmii.tags.grep(aPattern)

  unless choices.empty?
    curIdx = choices.index(Wmii.current_view.name)
    maxIdx = choices.length

    idx = curIdx.next % maxIdx rescue 0

    Wmii.focus_view choices[idx]
  end
end

# Numbers the view buttons displayed on the bar, from left to right.
def number_view_buttons
  Wmii.fs.bar.read.each_with_index do |b, i|
    Wmii.fs.bar[b].data = "#{i + 1}:#{b}"
  end
end


## wmii-2 style client detaching

DETACHED_TAG = 'status'

# Detach the current selection.
def detach_selection
  Wmii.selected_clients.each do |c|
    c.tags = DETACHED_TAG
  end
end

# Attach the most recently detached client
def attach_last_client
  if a = Wmii.get_view(DETACHED_TAG).areas.last
    if c = a.clients.last
      c.tags = Wmii.current_view.name
    end
  end
end
