# Abstractions for window manager stuff.
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

module Wmii
  SELECTION_TAG = 'SEL'

  # Searches for the client with the given ID and returns it. If the client is not found, *nil* is returned. The search is performed within the given places if they are specified.
  def find_client aClientId, aArea = nil, aView = nil
    aClientId = aClientId.to_i
    needle = Client.new("/client/#{aClientId}")

    if needle.exist?
      areas = []

      if aArea && aArea.exist?
        areas << aArea
      elsif aView && aView.exist?
        areas.concat aView.areas
      else
        needle.tags.map {|t| View.new("/#{t}")}.each do |v|
          areas.concat v.areas
        end
      end

      areas.each do |a|
        if a.indices.detect {|i| i == aClientId}
          return a[aClientId]
        end
      end
    end

    nil
  end

  # Encapsulates the window manager's state.
  module State
    ## state access

    # Returns the currently focused client.
    def focused_client
      Client.new("/view/sel/sel")
    end

    # Returns the currently focused area.
    def focused_area
      Area.new("/view/sel")
    end

    # Returns the currently focused view.
    def focused_view
      View.new("/view")
    end

    # Returns the current set of tags.
    def tags
      IxpFs.read('/tags').split
    end

    # Returns the current set of views.
    def views
      tags.map {|v| View.new "/#{v}"}
    end

    # Returns the current set of clients.
    def clients
      Area.new("/client").clients
    end


    ## state manipulation

    # Focuses the view with the given name.
    def focus_view aName
      View.new("/#{aName}").focus!
    end

    # Focuses the client which has the given ID.
    def focus_client aClientId
      if c = find_client(aClientId)
        v = (a = c.parent).parent

        v.focus!
        a.focus!
        c.focus!
      end
    end


    ## Multiple client selection

    # Returns a list of all selected clients in the currently focused view. If there are no selected clients, then the currently focused client is returned in the list.
    def selected_clients
      list = focused_view.areas.map do |a|
        a.clients.select {|c| c.selected?}
      end
      list.flatten!

      if list.empty?
        list << focused_client
      end

      list
    end

    # Un-selects all selected clients so that there is nothing selected.
    def select_none!
      View.new("/#{SELECTION_TAG}").unselect!
    end

    # Invokes the given block for each #selected_clients in a way that supports destructive operations, which change the number of areas in a view.
    def with_selection # :yields: client
      return unless block_given?

      curView = focused_view

      selected_clients.each do |c|
        # resolve stale paths caused by destructive operations
          unless c.exist?
            c = find_client(c.basename, nil, curView)
            c || next # skip upon failure
          end

        yield c
      end
    end
  end

  # Head of the window manager's hierarchy.
  class Root < IxpFs::Node
    include State

    def initialize
      super '/'
    end
  end

  # A region in the window manager's hierarchy.
  class Node < IxpFs::Node
    include Wmii

    def initialize aParentClass, aChildClass, *aArgs
      @parentClass = aParentClass
      @childClass = aChildClass
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
      if list = self.read
        list.grep(/^\d+$/).map {|s| s.to_i}
      else
        []
      end
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
      ['select', 'view'].each do |cmd|
        parent.ctl = "#{cmd} #{basename}"
      end
    end
  end

  class Client < Node
    def initialize *aArgs
      super Area, IxpFs::Node, *aArgs
    end

    undef index

    TAG_DELIMITER = "+"

    # Returns the tags associated with this client.
    def tags
      self['tags'].split(TAG_DELIMITER)
    end

    # Modifies the tags associated with this client.
    def tags= *aTags
      t = aTags.flatten.uniq
      self['tags'] = t.join(TAG_DELIMITER) unless t.empty?
    end

    # Evaluates the given block within the context of this client's list of tags.
    def with_tags &aBlock
      t = self.tags
      t.instance_eval(&aBlock)
      self.tags = t
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

  class Area < Node
    def initialize *aArgs
      super View, Client, *aArgs
    end

    alias clients children

    # Inserts the given clients at the bottom of this area.
    def push! *aClients
      clients.last.focus! if exist?
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

      clients.first.focus! if exist?
      setup_for_insertion! aClients.shift
      clients.first.ctl = 'swap down'

      dst = self.index
      aClients.each do |c|
        c.ctl = "sendto #{dst}"
      end
    end

    # Concatenates the given area to the bottom of this area.
    def concat! aArea
      push! aArea.clients
    end

    private
      # Updates the path of this area for proper insertion and inserts the given client.
      def setup_for_insertion! aFirstClient
        dstIdx = self.index
        maxIdx = parent.indices.last

        if dstIdx > maxIdx
          # move *near* final destination
            aFirstClient.ctl = "sendto #{maxIdx}"

            # recalculate b/c sendto can be destructive
              maxIdx = parent.indices.last
              maxCol = parent[maxIdx]

              aFirstClient = find_client(aFirstClient.index, maxCol)

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
      super IxpFs::Node, Area, *aArgs
    end

    alias areas children

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

        secCol.mode = 'default'
        # priCol.mode = 'max'
        priClient.focus!
      end
    end

    # Arranges the clients in this view, while maintaining their relative order, in a (at best) square grid.
    def grid! aMaxClientsPerColumn = nil
      # determine client distribution
        unless aMaxClientsPerColumn
          numClients = self.areas[1..-1].inject(0) do |count, area|
            count + area.clients.length
          end

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
          i = 1 # skip the floating area

          until i >= (areaList = self.areas).length
            a = areaList[i]


            a.mode = 'default'
            clientList = a.clients

            if clientList.length > aMaxClientsPerColumn
              # evict excess clients to next column
                emigrants = clientList[aMaxClientsPerColumn..-1]
                a.next.unshift! emigrants

            elsif clientList.length < aMaxClientsPerColumn
              # import clients from next column
                until (diff = aMaxClientsPerColumn - a.clients.length) == 0
                  immigrants = a.next.clients[0...diff]
                  break if immigrants.empty?

                  a.push! immigrants
                end
            end


            i += 1
          end
        end
    end
  end
end
