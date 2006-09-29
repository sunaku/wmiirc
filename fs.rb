# Abstractions for wmii's {IXP file system}[http://wmii.de/contrib/guide/wmii-3/guide-en/guide_en/node9.html] interface.
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

$:.unshift File.join(File.dirname(__FILE__), 'ruby-ixp', 'lib')
require 'ixp'

# Encapsulates access to the IXP file system.
module Ixp
  Client = IXP::Client.new

  # An entry in the IXP file system.
  class Node
    attr_reader :path

    # Obtains the IXP node at the given path. Unless it already exists, the given path is created when aCreateIt is asserted.
    def initialize aPath, aCreateIt = false
      @path = aPath.to_s.squeeze('/')
      create! if aCreateIt && !exist?
    end

    # Open this node for IO operation.
    def open *aArgs, &aBlock # :yields: IO
      Client.open @path, *aArgs, &aBlock
    end

    # Creates this node.
    def create!
      Client.create @path
    end

    # Deletes this node.
    def remove!
      Client.remove @path
    end

    # Writes the given content to this node.
    def write! aContent
      Client.write @path, aContent
    end

    # Returns the contents of this node or the names of all entries if this is a directory.
    def read
      cont = Client.read(@path)

      if cont.respond_to? :to_ary
        cont.map {|stat| stat.name}
      else
        cont
      end
    end

    # Tests if this node is a file.
    def file?
      Client.file? @path
    end

    # Tests if this node is a directory.
    def directory?
      Client.directory? @path
    end

    # Tests if this node exists in the file system.
    def exist?
      Client.exist? @path
    end

    # Returns the basename of this file's path.
    def basename
      File.basename @path
    end

    # Returns the dirname of this file's path.
    def dirname
      File.dirname @path
    end

    # Accesses the given sub-path and dereferences it (reads its contents) if specified.
    def [] aSubPath, aDeref = false
      child = Node.new("#{@path}/#{aSubPath}")

      if aDeref
        child.read
      else
        child
      end
    end

    # Writes the given content to the given sub-path.
    def []= aSubPath, aContent
      self[aSubPath].write! aContent
    end

    # Provides access to sub-nodes through method calls.
    #
    # :call-seq:
    #   node.child = value  -> value
    #   node.child (tree)   -> Node
    #   node.child (leaf)   -> child.read
    #
    def method_missing aMeth, *aArgs
      case aMeth.to_s
        when /=$/
          self[$`] = *aArgs

        else
          if (n = self[aMeth]).file?
            n.read
          else
            n
          end
      end
    end
  end
end
