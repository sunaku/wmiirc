$:.unshift File.join(File.dirname(__FILE__), 'ruby-ixp', 'lib')
require 'ixp'

# Encapsulates access to a file/directory in the IXP file system.
class IxpNode
  attr_reader :path

  def initialize aPath
    @path = aPath

    unless defined? @@ixp
      begin
        @@ixp = IXP::Client.new
      rescue Errno::ECONNREFUSED
        retry
      end
    end
  end

  # Creates a file at the given path and returns it.
  def create aPath
    begin
      @@ixp.create aPath
      IxpNode.new aPath
    rescue IXP::IXPException => e
      puts "#{e.backtrace.first}: #{e}"
    end
  end

  # Deletes the given path.
  def remove aPath
    begin
      @@ixp.remove aPath
    rescue IXP::IXPException => e
      puts "#{e.backtrace.first}: #{e}"
    end
  end

  # Writes the given content to the given path.
  def write aPath, aContent
    begin
      @@ixp.open(aPath) do |f|
        f.write aContent.to_s
      end
    rescue IXP::IXPException => e
      puts "#{e.backtrace.first}: #{e}"
    end
  end

  # Reads from the given path and returns the content. If the path is a directory, then the names of all files in that directory are returned.
  def read aPath
    begin
      @@ixp.open(aPath) do |f|
        if f.respond_to? :next # read file-names from directory
          names = ''

          while i = f.next
            names << i.name << "\n"
          end

          names
        else # read file contents
          f.read_all
        end
      end
    rescue IXP::IXPException => e
      puts "#{e.backtrace.first}: #{e}"
    end
  end

  # Provides easy access to files contained within this file.
  def method_missing aMeth, *aArgs
    if aMeth.to_s =~ /=$/
      write "#{@path}/#{$`}", *aArgs
    elsif content = read("#{@path}/#{aMeth}")
      content
    else
      super
    end
  end
end
