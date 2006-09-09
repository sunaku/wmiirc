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

require 'IxpNode'
require 'find'

# Ruby interface to WMII.
class Wmii < IxpNode
  SELECTION_TAG = 'SEL'
  DETACHED_TAG = 'status'

  attr_reader :config

  def initialize
    super "/"
    @config = IxpNode.new('/def')
  end

  ##
  # WM state access
  #

  # Returns the currently focused client.
  def current_client
    Client.new("/view/sel/sel")
  end

  # Returns the currently focused area.
  def current_area
    Area.new("/view/sel")
  end

  # Returns the currently focused view.
  def current_view
    View.new("/view")
  end

  # Returns the current set of tags.
  def tags
    read('/tags').split
  end

  # Returns the current set of views.
  def views
    tags.map {|v| View.new "/#{v}"}
  end

  # Returns the current set of clients.
  def clients
    Area.new("/client").clients
  end


  ##
  # WM state manipulation
  #

  # Focuses the view with the given name.
  def focus_view aName
    View.new("/#{aName}").focus
  end

  # Focuses the client which has the given ID.
  def focus_client aClientId
    views.each do |v|
      v.areas.each do |a|
        a.clients.each do |c|
          if c.index == aClientId
            v.focus
            a.focus
            c.focus
            return
          end
        end
      end
    end
  end

  # Changes the current view to an adjacent one (:left or :right).
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


  ##
  # View arrangement
  #

  # Applies wmii-2 style tiling layout to the current view while maintaining the order of clients in the current view. Only the first client in the primary column is kept; all others are evicted to the *top* of the secondary column. Any teritiary, quaternary, etc. columns are squeezed into the *bottom* of the secondary column.
  def apply_tiling_layout
    areaList = read('/view').split.grep(/^[^0]\d*$/)

    unless areaList.empty?
      # keep only the first client in zoomed area
        write '/view/2/ctl', 'select 0'

        read('/view/1').split.grep(/^[^0]\d*$/).length.times do |i|
          write '/view/1/1/ctl', 'sendto next'
          write '/view/2/sel/ctl', 'swap up' if i.zero?
        end

        # write '/view/1/mode', 'max'

      # squeeze unzoomed clients into secondary column
        if secondary = read('/view/2')
          write '/view/2/ctl', "select #{secondary.split.grep(/^\d+$/).last}"

          (areaList.length - 2).times do
            read('/view/3').split.grep(/^\d+$/).length.times do
              write '/view/3/0/ctl', 'sendto prev'
            end
          end

          write '/view/2/mode', 'default'
        end
    end
  end

  # Applies wmii-2 style grid layout to the current view while maintaining the order of clients in the current view. If the maximum number of clients per column, the distribution of clients among the columns is calculated according to wmii-2 style. Only the first client in the primary column is kept; all others are evicted to the *top* of the secondary column. Any teritiary, quaternary, etc. columns are squeezed into the *bottom* of the secondary column.
  def apply_grid_layout aMaxClientsPerColumn = nil
    # determine client distribution
      unless aMaxClientsPerColumn
        numClients = 0

        read('/view').split.grep(/^[^0]\d*$/).each do |column|
          numClients += read("/view/#{column}").split.grep(/^\d+$/).length
        end

        return if numClients.zero?


        numColumns = Math.sqrt(numClients)
        aMaxClientsPerColumn = (numClients / numColumns).round
      end

    # distribute the clients
      if aMaxClientsPerColumn <= 0
        # squeeze all clients into a single column
          while clientList = read('/view/2')
            numClients = clientList.split.grep(/^\d+$/).length
            numClients.times do
              write '/view/2/0/ctl', 'sendto prev'
            end
          end
      else
        begin
          columnList = read('/view').split.grep(/^[^0]\d*$/)

          columnList.each do |column|
            if clientList = read("/view/#{column}")
              write "/view/#{column}/mode", 'default'	# set *equal* layout for column

              numClients = clientList.split.grep(/^\d+$/).length
              nextColumn = column.to_i + 1

              if numClients > aMaxClientsPerColumn
                # evict excess clients to next column
                  write "/view/#{nextColumn}/ctl", 'select 0'

                  (numClients - aMaxClientsPerColumn).times do |i|
                    write "/view/#{column}/#{aMaxClientsPerColumn}/ctl", 'sendto next'
                    write "/view/#{nextColumn}/sel/ctl", 'swap up' if i.zero?
                  end

              elsif numClients < aMaxClientsPerColumn
                # import clients from next column
                  write "/view/#{column}/ctl", "select #{read("/view/#{column}").split.grep(/^\d+$/).last}"

                  (aMaxClientsPerColumn - numClients).times do
                    write "/view/#{nextColumn}/0/ctl", 'sendto prev'
                  end
              end
            end
          end
        end until columnList.length == read('/view').split.grep(/^[^0]\d*$/).length
      end
  end


  ##
  # Multiple client selection
  #

  # Returns a list of all selected clients in the current view. If there are no selected clients, then the currently focused client is returned in the list.
  def selected_clients
    list = current_view.areas.map do |a|
      a.clients.select {|c| c.selected?}
    end
    list.flatten!

    if list.empty?
      list << current_client
    end

    list
  end

  # Un-selects all selected clients.
  def select_none
    View.new("/#{SELECTION_TAG}").unselect!
  end


  ##
  # wmii-2 style client detaching
  #

  # Detach the currently selected client
  def detach_current_client
    current_client.tags = DETACHED_TAG
  end

  # Attach the most recently detached client
  def attach_last_client
    if a = View.new("/#{DETACHED_TAG}").areas.first
      if c = a.clients.first
        c.tags = current_view.name
      end
    end
  end


  ##
  # Utility methods
  #

  # Shows a WM menu with the given content and returns its output.
  def show_menu aContent
    output = nil

    IO.popen('wmiimenu', 'r+') do |menu|
      menu.write aContent
      menu.close_write

      output = menu.read
    end

    output
  end

  # Returns a list of program names available in the given paths.
  def find_programs *aPaths
    list = []

    Find.find(*aPaths) do |f|
      if File.executable?(f) && !File.directory?(f)
        list << File.basename(f)
      end
    end

    list.uniq.sort
  end


  ##
  # Subclasses for more abstraction
  #

  # Encapsulates a graphical region and its file system properties.
  class Container < IxpNode
    # Returns a list of indices of items in this region.
    def indices
      if list = read(@path)
        list.split.grep(/^\d+$/)
      else
        []
      end
    end

    # Returns a list of items in this region.
    def subordinates
      if @subordinateClass
        # go in reverse order to accomodate destructive procedures
        indices.reverse.map {|i| @subordinateClass.new "#{@path}/#{i}"}
      else
        []
      end
    end

    # Adds all clients in this region to the selection.
    def select!
      subordinates.each do |s|
        s.select!
      end
    end

    # Removes all clients in this region from the selection.
    def unselect!
      subordinates.each do |s|
        s.unselect!
      end
    end

    # Inverts the selection of clients in this region.
    def invert_selection!
      subordinates.each do |s|
        s.invert_selection!
      end
    end

    # Puts focus on this region.
    def focus
      ['select', 'view'].each do |cmd|
        return if write "#{@path}/../ctl", "#{cmd} #{File.basename @path}"
      end
    end
  end

  # Represents a running, graphical program.
  class Client < Container
    TAG_DELIMITER = "+"

    # Returns the tags associated with this client.
    def tags
      read("#{@path}/tags").split(TAG_DELIMITER)
    end

    # Modifies the tags associated with this client.
    def tags= *aTags
      t = aTags.flatten.uniq
      write "#{@path}/tags", t.join(TAG_DELIMITER) unless t.empty?
    end

    # Evaluates the given block within the context of this client's list of tags.
    def with_tags &aBlock
      t = self.tags
      t.instance_eval(&aBlock)
      self.tags = t
    end

    # Returns true if this client is included in the selection.
    def selected?
      tags.include? SELECTION_TAG
    end

    def select!
      with_tags do
        unshift SELECTION_TAG
      end
    end

    def unselect!
      with_tags do
        delete SELECTION_TAG
      end
    end

    def invert_selection!
      if selected?
        unselect!
      else
        select!
      end
    end
  end

  class Area < Container
    def initialize *args
      super
      @subordinateClass = Client
    end

    alias clients subordinates
  end

  class View < Container
    def initialize *args
      super
      @subordinateClass = Area
    end

    alias areas subordinates
  end
end
