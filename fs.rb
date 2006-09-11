=begin
  Copyright 2006 Suraj N. Kurapati
  Copyright 2006 Stephan Maka

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
module IxpFs
  begin
    @@ixp = IXP::Client.new
  rescue Errno::ECONNREFUSED
    retry
  end

  # Creates a file at the given path and returns it.
  def self.create aPath
    begin
      @@ixp.create aPath
    rescue IXP::IXPException => e
      puts e, e.backtrace
    end
  end

  # Deletes the given path.
  def self.remove aPath
    begin
      @@ixp.remove aPath
    rescue IXP::IXPException => e
      puts e, e.backtrace
    end
  end

  # Writes the given content to the given path.
  def self.write aPath, aContent
    open(aPath) do |f|
      f.write aContent.to_s
      # puts '', "#{self.class}.write #{aPath}, #{aContent.inspect}", caller # if $DEBUG
    end
  end

  # Reads from the given path and returns the content. If the path is a directory, then the names of all files in that directory are returned.
  def self.read aPath
    open(aPath) do |f|
      if f.is_a? IXP::Directory
        names = []

        while i = f.next
          names << i.name
        end

        names

      else # read file contents
        f.read_all
      end
    end
  end

  def self.file? aPath
    open(aPath) {|f| f.instance_of? IXP::File}
  end

  def self.directory? aPath
    open(aPath) {|f| f.instance_of? IXP::Directory}
  end

  def self.exist? aPath
    open(aPath) {true}
  end

  def self.open aPath # :yields: IO
    if block_given?
      begin
        @@ixp.open(aPath) do |f|
          return yield(f)
        end
      rescue IXP::IXPException
      end
    end

    nil
  end
end

# Encapsulates access to an entry in the IXP file system.
class IxpNode
  attr_reader :path

  def initialize aPath, aCreateIt = false
    @path = aPath.squeeze('/')
    create! if aCreateIt && !exist?
  end

  def create!
    IxpFs.create @path
  end

  def remove!
    IxpFs.remove @path
  end

  def write! aContent
    IxpFs.write @path, aContent
  end

  def read
    IxpFs.read @path
  end

  def file?
    IxpFs.file? @path
  end

  def directory?
    IxpFs.directory? @path
  end

  def exist?
    IxpFs.exist? @path
  end

  # Accesses the given sub-path.
  def [] aSubPath
    child = IxpNode.new("#{@path}/#{aSubPath}")

    if child.file?
      child.read
    else
      child
    end
  end

  # Writes to the given sub-path.
  def []= aSubPath, aContent
    child = IxpNode.new("#{@path}/#{aSubPath}")
    child.write! aContent if child.file?
  end

  # Provides easy access to sub-nodes.
  def method_missing aMeth, *aArgs
    if aMeth.to_s =~ /=$/
      self[$`] = *aArgs
    else
      self[aMeth]
    end
  end
end
