## Utility methods used by wmiirc.
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

# Shows a WM menu with the given content and returns its output.
def show_menu *aContent
  aContent.flatten!
  output = nil

  IO.popen('wmiimenu', 'r+') do |menu|
    menu.write aContent.join("\n")
    menu.close_write

    output = menu.read
  end

  output
end
