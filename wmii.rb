# Ruby interface to WMII.

$:.unshift File.join(File.dirname(__FILE__), 'ruby-ixp/lib')
require 'ixp'

require 'find'
require 'singleton'

class Wmii
	include Singleton

	def initialize
		begin
			@cl = IXP::Client.new
		rescue Errno::ECONNREFUSED
			retry
		end
	end

	def create(file)
		@cl.create(file)
	rescue IXP::IXPException => e
		puts "#{e.backtrace.first}: #{e}"
	end

	def remove(file)
		@cl.remove(file)
	rescue IXP::IXPException => e
		puts "#{e.backtrace.first}: #{e}"
	end

	# Writes the given content to the given WM path, and returns +true+ if the operation was successful.
	# def write aPath, aContent
	#		begin
	#			IO.popen("wmiir write #{aPath}", 'w') do |io|
	#				puts "wmiir: writing '#{aContent}' into '#{aPath}'" if $DEBUG
	#				io.write aContent
	#			end
	#		rescue Errno::EPIPE
	#			return false
	#		end

	#		$? == 0
	# end

	def write(file, data)
		@cl.open(file) { |f| f.write(data.to_s) }
	rescue IXP::IXPException => e
		puts "#{e.backtrace.first}: #{e}"
	end

	# def read aPath
	#		`wmiir read #{aPath}`
	# end

	def read(file)
		@cl.open(file) do |f|
			if f.respond_to? :next	# read directory listing
				str = ''

				while i = f.next
					str << i.name << "\n"
				end

				str
			else
				f.read_all
			end
		end
	rescue IXP::IXPException => e
		puts "#{e.backtrace.first}: #{e}"
	end

	# Shows the view with the given name.
	def showView aName
		write '/ctl', "view #{aName}"
	end

	# Shows a WM menu with the given content and returns its output.
	def showMenu aContent
		output = nil

		IO.popen('wmiimenu', 'r+') do |menu|
			menu.write aContent
			menu.close_write

			output = menu.read
		end

		output
	end

	# Shows the client which has the given ID.
	def showClient aClientId
		read('/tags').split.each do |view|
			read("/#{view}").split.grep(/^\d+$/).each do |column|
				read("/#{view}/#{column}").split.grep(/^\d+$/).each do |client|
					if read("/#{view}/#{column}/#{client}/index") == aClientId
						showView view
						write '/view/ctl', "select #{column}"
						write "/view/sel/ctl", "select #{client}"
						return
					end
				end
			end
		end
	end

	DETACHED_TAG = 'status'

	# Detach the currently selected client
	def detachClient
		write '/view/sel/sel/tags', DETACHED_TAG
	end

	# Attach the most recently detached client
	def attachClient
		if areaList = read("/#{DETACHED_TAG}")
			area = areaList.split.grep(/^\d+$/).last

			if clientList = read("/#{DETACHED_TAG}/#{area}")
				client = clientList.split.grep(/^\d+$/).last

				write "/#{DETACHED_TAG}/#{area}/#{client}/tags", read('/view/name')
			end
		end
	end

	# Changes the current view to an adjacent one (:left or :right).
	def cycleView aTarget
		tags = read('/tags').split

		curTag = read('/view/name')
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

		newTag = tags[newIndex]

		showView newTag
	end

	# Renames the given view and sends its clients along for the ride.
	def renameView aOld, aNew
		read('/client').split.each do |id|
			tags = read("/client/#{id}/tags")

			write "/client/#{id}/tags", tags.gsub(aOld, aNew).squeeze('+')
		end
	end

	# Returns a list of program names available in the given paths.
	def findPrograms *aPaths
		list = []

		Find.find(*aPaths) do |f|
			if File.executable?(f) && !File.directory?(f)
				list << File.basename(f)
			end
		end

		list.uniq.sort
	end
end
