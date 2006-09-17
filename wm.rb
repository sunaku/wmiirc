# Abstractions for the window manager.
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

require 'fs'

# Encapsulates access to the window manager.
module Wmii
  ## state access

  # Returns the root of IXP file system hierarchy.
  def Wmii.fs
    Ixp::Node.new '/'
  end

  # Returns the currently focused client.
  def Wmii.current_client
    Client.new("/view/sel/sel")
  end

  # Returns the currently focused area.
  def Wmii.current_area
    Area.new("/view/sel")
  end

  # Returns the currently focused view.
  def Wmii.current_view
    View.new("/view")
  end

  # Returns the current set of tags.
  def Wmii.tags
    Ixp.read('/tags').split
  end

  # Returns the current set of views.
  def Wmii.views
    tags.map {|v| get_view v}
  end

  # Returns the current set of clients.
  def Wmii.clients
    Area.new("/client").clients
  end

  # Returns the client which has the given ID.
  def Wmii.get_client aId
    Client.new("/client/#{aId}")
  end

  # Returns the view which has the given name.
  def Wmii.get_view aName
    View.new("/#{aName}")
  end

  # Searches for a client, which has the given ID, in the given places. If no places are specified, then all views are searched. If the client is not found, *nil* is returned.
  def Wmii.find_client aClientId, aArea = nil, aView = nil
    aClientId = aClientId.to_i
    needle = Wmii.get_client(aClientId)

    if needle.exist?
      areas = []

      if aArea && aArea.exist?
        areas << aArea

      elsif aView && aView.exist?
        areas.concat aView.areas

      else
        needle.tags.map {|t| get_view t}.each do |v|
          areas.concat v.areas
        end
      end

      areas.each do |a|
        if a.indices.detect {|i| i == aClientId}
          return a[aClientId]
        end
      end
    end

    puts "could not find client #{aClientId} in area #{aArea.inspect} or view #{aView.inspect}" if $DEBUG

    nil
  end


  ## state manipulation

  # Focuses the view with the given name.
  def Wmii.focus_view aName
    get_view(aName).focus!
  end

  # Focuses the area with the given ID in the current view.
  def Wmii.focus_area aId
    Wmii.current_view[aId].focus!
  end

  # Focuses the client which has the given ID.
  def Wmii.focus_client aId
    if c = find_client(aId)
      v = (a = c.parent).parent

      v.focus!
      a.focus!
      c.focus!
    end
  end


  ## Multiple client selection

  SELECTION_TAG = 'SEL'

  # Returns a list of all selected clients in the currently focused view. If there are no selected clients, then the currently focused client is returned in the list.
  def Wmii.selected_clients
    list = current_view.areas.map do |a|
      a.clients.select {|c| c.selected?}
    end
    list.flatten!

    if list.empty?
      list << current_client
    end

    list
  end

  # Un-selects all selected clients so that there is nothing selected.
  def Wmii.select_none!
    get_view(SELECTION_TAG).unselect!
  end


  ## subclasses for abstraction

  # A region in the window manager's hierarchy.
  class Node < Ixp::Node
    def initialize aParentClass, aChildClass, aFocusCommand, *aArgs
      @parentClass = aParentClass
      @childClass = aChildClass
      @focusCmd = aFocusCommand
      super(*aArgs)
    end

    # Returns a child with the given sub-path.
    def [] *args
      child = super

      if child.respond_to? :path
        child = @childClass.new(child.path)
      end

      child
    end

    # Returns the parent of this region.
    def parent
      @parentClass.new File.dirname(@path)
    end

    # Returns the index of this region in the parent.
    def index
      basename.to_i
    end

    # Returns the next region in the parent.
    def next
      parent[self.index + 1]
    end

    # Returns a list of indices of items in this region.
    def indices
      read.grep(/^\d+$/).map {|s| s.to_i} rescue []
    end

    # Returns the number of items in this region.
    def length
      indices.length
    end

    # Returns a list of items in this region.
    def children
      indices.map {|i| @childClass.new "#{@path}/#{i}"}
    end

    # Adds all clients in this region to the selection.
    def select!
      children.each do |s|
        s.select!
      end
    end

    # Removes all clients in this region from the selection.
    def unselect!
      children.each do |s|
        s.unselect!
      end
    end

    # Inverts the selection of clients in this region.
    def invert_selection!
      children.each do |s|
        s.invert_selection!
      end
    end

    # Puts focus on this region.
    def focus!
      parent.ctl = "#{@focusCmd} #{basename}"
    end
  end

  class Client < Node
    def initialize *aArgs
      super Area, Ixp::Node, :select, *aArgs
    end

    undef index # it prevents access to ./index file


    TAG_DELIMITER = "+"

    # Returns the tags associated with this client.
    def tags
      self[:tags].split(TAG_DELIMITER)
    end

    # Modifies the tags associated with this client.
    def tags= *aTags
      t = aTags.flatten.uniq
      self[:tags] = t.join(TAG_DELIMITER) unless t.empty?
    end

    # Evaluates the given block within the context of this client's list of tags.
    def with_tags &aBlock
      t = self.tags
      t.instance_eval(&aBlock)
      self.tags = t
    end

    # Adds the given tags to this client.
    def tag! *aTags
      with_tags do
        push(*aTags)
      end
    end

    # Removes the given tags from this client.
    def untag! *aTags
      with_tags do
        delete(*aTags)
      end
    end

    # Checks if this client is included in the current selection.
    def selected?
      tags.include? SELECTION_TAG
    end

    def select!
      with_tags do
        unshift SELECTION_TAG
      end
    end

    def unselect!
      untag! SELECTION_TAG
    end

    def invert_selection!
      if selected?
        unselect!
      else
        select!
      end
    end
  end

  class Area < Node
    def initialize *aArgs
      super View, Client, :select, *aArgs
    end

    alias clients children

    # Inserts the given clients at the bottom of this area.
    def push! *aClients
      if target = clients.last
        target.focus!
      end

      insert! aClients
    end

    # Inserts the given clients after the currently focused client in this area.
    def insert! *aClients
      aClients.flatten!
      return if aClients.empty?

      setup_for_insertion! aClients.shift

      dst = self.index
      aClients.each do |c|
        c.ctl = "sendto #{dst}"
      end
    end

    # Inserts the given clients at the top of this area.
    def unshift! *aClients
      aClients.flatten!
      return if aClients.empty?

      if target = clients.first
        target.focus!
      end

      setup_for_insertion! aClients.shift

      if top = clients.first
        top.ctl = 'swap down'
      end

      dst = self.index
      aClients.each do |c|
        c.ctl = "sendto #{dst}"
      end
    end

    # Concatenates the given area to the bottom of this area.
    def concat! aArea
      push! aArea.clients
    end

    # Ensures that this area has at most the given number of clients. Areas to the right of this one serve as a buffer into which excess clients are evicted and from which deficit clients are imported.
    def length= aMaxClients
      return if aMaxClients < 0
      len = self.length

      if len > aMaxClients
        self.next.unshift! clients[aMaxClients..-1]

      elsif len < aMaxClients
        until (diff = aMaxClients - length) == 0
          immigrants = self.next.clients[0...diff]
          break if immigrants.empty?

          push! immigrants
        end
      end
    end

    private
      # Updates the path of this area for proper insertion and inserts the given client.
      def setup_for_insertion! aFirstClient
        raise ArgumentError, 'nonexistent client' unless aFirstClient.exist?

        dstIdx = self.index
        maxIdx = parent.indices.last

        if dstIdx > maxIdx
          # move *near* final destination
            clientId = aFirstClient.index
            aFirstClient.ctl = "sendto #{maxIdx}"

            # recalculate b/c sendto can be destructive
              maxIdx = parent.indices.last
              maxCol = parent[maxIdx]

              aFirstClient = Wmii.find_client(clientId, maxCol)

          # move *into* final destination
            if maxCol.indices.length > 1
              aFirstClient.ctl = "sendto next"
              dstIdx = maxIdx + 1
            else
              dstIdx = maxIdx
            end

          @path = "#{dirname}/#{dstIdx}"

        else
          aFirstClient.ctl = "sendto #{dstIdx}"
        end
      end
  end

  class View < Node
    def initialize *aArgs
      super Ixp::Node, Area, :view, *aArgs
    end

    alias areas children

    # Iterates over columns in this view such that destructive operations are supported. If specified, the iteration starts with the column which has the given index.
    # Note that the floating area is not considered to be a column.
    def each_column aStartIdx = 1 # :yields: area
      return unless block_given?

      if (i = aStartIdx.to_i) < 1
        i = 1
      end

      until i >= (areaList = self.areas).length
        yield areaList[i]
        i += 1
      end
    end

    # Arranges the clients in this view, while maintaining their relative order, in the tiling fashion of LarsWM. Only the first client in the primary column is kept; all others are evicted to the *top* of the secondary column. Any subsequent columns are squeezed into the *bottom* of the secondary column.
    def tile!
      numAreas = self.indices.length

      if numAreas > 1
        priCol, secCol, extCol = self[1], self[2], self[3]

        # keep only the first client in primary column
          priClient, *rest = priCol.clients
          secCol.unshift! rest

        # squeeze extra columns into secondary column
          if numAreas > 3
            (numAreas - 2).times do
              secCol.concat! extCol
            end
          end

        secCol.mode = :default
        #priCol.mode = :max
        priClient.focus!
      end
    end

    # Arranges the clients in this view, while maintaining their relative order, in a (at best) square grid.
    def grid! aMaxClientsPerColumn = nil
      # determine client distribution
        unless aMaxClientsPerColumn
          numClients = num_grounded_clients
          return unless numClients > 1

          numColumns = Math.sqrt(numClients)
          aMaxClientsPerColumn = (numClients / numColumns).round
        end

      # distribute the clients
        if aMaxClientsPerColumn <= 0
          # squeeze all clients into a single column
            areaList = self.areas

            (areaList.length - 2).times do
              areaList[1].concat! areaList[2]
            end

        else
          each_column do |a|
            a.length = aMaxClientsPerColumn
            a.mode = :default
          end
        end
    end

    # Arranges the clients in this view, while maintaining their relative order, in a (at best) equilateral triangle. However, the resulting arrangement appears like a diamond because wmii does not waste screen space.
    def diamond!
      numClients = num_grounded_clients
      subtriArea = numClients / 2
      crestArea = numClients % subtriArea

      # build fist sub-triangle upwards
        height = area = 0
        lastCol = nil

        each_column do |col|
          if area < subtriArea
            height += 1

            col.length = height
            area += height

            col.mode = :default
            lastCol = col
          else
            break
          end
        end

      # build crest of overall triangle
        if crestArea > 0
          lastCol.length = height + crestArea
        end

      # build second sub-triangle downwards
        each_column(lastCol.index + 1) do |col|
          if area > 0
            col.length = height
            area -= height

            height -= 1
          else
            break
          end
        end
    end

    private
      # Returns the number of clients in the non-floating areas of this view.
      def num_grounded_clients
        if ground = areas[1..-1]
          ground.inject(0) do |count, area|
            count + area.length
          end
        else
          0
        end
      end
  end
end

class Array
  alias original_each each

  # Supports destructive operations on each client in this array.
  def each
    return unless block_given?

    original_each do |c|
      if c.is_a? Wmii::Client
        # resolve stale paths caused by destructive operations
        unless c.exist?
          puts "\n trying to resolve nonexistent client: #{c.inspect}" if $DEBUG

          c = Wmii.find_client(c.basename, nil, Wmii.current_view)
          next unless c

          puts "resolution OK: #{c.inspect}" if $DEBUG
         end
      end

      yield c
    end
  end
end
