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

require 'find'
require 'wm'

include Wmii
include Wmii::State

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

  list.uniq.sort
end

# Shows a menu with the given items and returns the chosen item. If nothing was chosen, an empty string is returned.
def show_menu *aChoices
  aChoices.flatten!
  output = nil

  IO.popen('wmiimenu', 'r+') do |menu|
    menu.write aChoices.join("\n")
    menu.close_write

    output = menu.read
  end

  output
end

# Focuses the client chosen from a menu.
def focus_client_from_menu
  choices = clients.map do |c|
    format "%d. [%s] %s", c.index, c.tags, c.name.downcase
  end

  target = show_menu(choices)

  unless target.empty?
    focus_client target.scan(/\d+/).first
  end
end

# Changes the tag, chosen from a menu, of each selected client.
# The {+tag -tag idea}[http://zimbatm.oree.ch/articles/2006/06/15/wmii-3-and-ruby] is from Jonas Pfenniger.
def change_tag_from_menu
  choices = tags.map {|t| [t, "+#{t}", "-#{t}"]}.flatten
  target = show_menu(choices)

  with_selection do |c|
    c.with_tags do
      case target
        when /^\+/
          push $'

        when /^\-/
          delete $'

        else
          clear
          push target
      end
    end
  end
end

# Send selected clients to temporary view or switch back again.
def toggle_temp_view
  curView = current_view.name

  if curView =~ /~\d+$/
    with_selection do |c|
      c.with_tags do
        delete curView
        push $` if empty?
      end
    end

    focus_view $`

  else
    tmpView = "#{curView}~#{Time.now.to_i}"

    with_selection do |c|
      c.with_tags do
        push tmpView
      end
    end

    focus_view tmpView
    current_view.grid!
  end
end

# Puts focus on an adjacent view (:left or :right).
def cycle_view aTarget
  tags = self.tags
  curTag = current_view.name
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

  focus_view tags[newIndex]
end


## wmii-2 style client detaching

DETACHED_TAG = 'status'

# Detach the current selection.
def detach_selection
  selected_clients.each do |c|
    c.tags = DETACHED_TAG
  end
end

# Attach the most recently detached client
def attach_last_client
  if a = View.new("/#{DETACHED_TAG}").areas.last
    if c = a.clients.last
      c.tags = current_view.name
    end
  end
end
