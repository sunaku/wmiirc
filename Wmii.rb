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

# Encapsulates a graphical region in the window manager.
class Container < IxpNode
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
    File.basename(@path).to_i
  end

  # Returns the next region in the parent.
  def next
    parent[self.index + 1]
  end

  # Returns a list of indices of items in this region.
  def indices
    if list = self.read
      list.split.grep(/^\d+$/)
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
      parent.ctl = "#{cmd} #{File.basename @path}"
    end
  end
end

# Ruby interface to WMII.
class Wmii < Container
  SELECTION_TAG = 'SEL'
  DETACHED_TAG = 'status'

  def initialize
    super IxpNode, View, '/'
  end


  ## access to WM state

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


  ## WM state manipulation

  # Focuses the view with the given name.
  def focus_view aName
    View.new("/#{aName}").focus!
  end

  # Focuses the client which has the given ID.
  def focus_client aClientId
    needle = Client.new("/client/#{aClientId}")
    haystack = needle.tags.map {|t| View.new("/#{t}")}

    haystack.each do |v|
      v.areas.each do |a|
        if a.indices.detect {|i| i == aClientId}
          v.focus!
          a.focus!
          a[aClientId].focus!
          return
        end
      end
    end
  end

  # Changes the currently focused view to an adjacent one (:left or :right).
  def cycle_view aTarget
    tags = self.tags
    curTag = focused_view.name
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

  # Un-selects all selected clients.
  def select_none
    View.new("/#{SELECTION_TAG}").unselect!
  end

  # Invokes the given block for each client in the selection.
  def with_selection # :yields: client
    return unless block_given?

    oldJobs = []

    loop do
      selection = selected_clients
      curJobs = selection.map {|c| c.index}

      pending = (curJobs - oldJobs)
      break if pending.empty?

      job = pending.shift
      yield selection.detect {|i| i.index == job}
      oldJobs << job
    end
  end


  ## wmii-2 style client detaching

  # Detach the current selection.
  def detach_selection
    selected_clients.each do |c|
      c.tags = DETACHED_TAG
    end
  end

  # Attach the most recently detached client
  def attach_last_client
    if a = View.new("/#{DETACHED_TAG}").areas.first
      if c = a.clients.first
        c.tags = focused_view.name
      end
    end
  end


  ## Utility methods

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


  ## Subclasses for abstraction

  # Represents a running, graphical program.
  class Client < Container
    def initialize *aArgs
      super Area, IxpNode, *aArgs
    end

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

  class Area < Container
    def initialize *aArgs
      super View, Client, *aArgs
    end

    alias clients children

    # Inserts the given clients at the bottom of this area.
    def push! *aClients
      return if aClients.empty?

      unless (list = clients).empty?
        list.last.focus!
      end

      insert!(*aClients)
    end

    # Inserts the given clients after the currently focused client in this area.
    def insert! *aClients
      return if aClients.empty?

      dstIdx = setup_for_insertion(aClients.shift)

      aClients.each do |c|
        c.ctl = "sendto #{dstIdx}"
      end
    end

    # Inserts the given clients at the top of this area.
    def unshift! *aClients
      return if aClients.empty?

      unless (list = clients).empty?
        list.first.focus!
      end

      dstIdx = setup_for_insertion(aClients.shift)
      parent[dstIdx].sel.ctl = 'swap up'

      aClients.each do |c|
        c.ctl = "sendto #{dstIdx}"
      end
    end

    # Concatenates the given area to the bottom of this area.
    def concat! aArea
      push!(*aArea.clients)
    end

    private
      # Sets up this area for insertion and returns the area ID into which insertion is performed.
      def setup_for_insertion aFirstClient
        dstIdx = self.index
        maxIdx = parent.indices.length - 1

        if dstIdx > maxIdx
          aFirstClient.ctl = "sendto #{maxIdx}"

          parent[maxIdx].sel.ctl = "sendto next"
          dstIdx = maxIdx.next
        else
          aFirstClient.ctl = "sendto #{dstIdx}"
        end

        dstIdx
      end
  end

  class View < Container
    def initialize *aArgs
      super IxpNode, Area, *aArgs
    end

    alias areas children

    # Applies wmii-2 style tiling layout to this view while maintaining its order of clients. Only the first client in the primary column is kept; all others are evicted to the *top* of the secondary column. Any subsequent columns are squeezed into the *bottom* of the secondary column.
    def tile!
      numAreas = self.indices.length

      if numAreas > 1
        priCol, secCol, extCol = self[1], self[2], self[3]

        # keep only the first client in primary column
          priClient, *rest = priCol.clients
          secCol.unshift!(*rest)

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

    # Applies wmii-2 style grid layout to this view while maintaining its order of clients. If the maximum number of clients per column, the distribution of clients among the columns is calculated according to wmii-2 style. Only the first client in the primary column is kept; all others are evicted to the *top* of the secondary column. Any teritiary, quaternary, etc. columns are squeezed into the *bottom* of the secondary column.
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
          i = 1

          until i >= (areaList = self.areas).length
            a = areaList[i]


            a.mode = 'default'
            clientList = a.clients

            if clientList.length > aMaxClientsPerColumn
              # evict excess clients to next column
                a.next.unshift!(*clientList[aMaxClientsPerColumn..-1])

            elsif clientList.length < aMaxClientsPerColumn
              # import clients from next column
                until (diff = aMaxClientsPerColumn - a.clients.length) == 0
                  pool = a.next.clients[0...diff]
                  break if pool.empty?

                  a.push!(*pool)
                end
            end


            i += 1
          end
        end
    end
  end
end
