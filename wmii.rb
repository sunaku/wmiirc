# Ruby interface to WMII.

require 'find'

module Wmii
	# Writes the given content to the given WM path, and returns +true+ if the operation was successful.
	def Wmii.write aPath, aContent
		begin
			IO.popen("wmiir write #{aPath}", 'w') do |io|
				puts "wmiir: writing '#{aContent}' into '#{aPath}'" if $DEBUG
				io.write aContent
			end
		rescue Errno::EPIPE
			return false
		end

		$? == 0
	end

	# Reads the filenames from a long listing of the given WM path.
	def Wmii.readList aPath
		`wmiir read #{aPath}`.scan(/\S+$/)
	end

	# Shows the view with the given name.
	def Wmii.showView aName
		Wmii.write '/ctl', "view #{aName}"
	end

	# Shows a WM menu with the given content and returns its output.
	def Wmii.showMenu aContent
		output = nil

		IO.popen('wmiimenu', 'r+') do |menu|
			menu.write aContent
			menu.close_write

			output = menu.read
		end

		output
	end

	# Shows the client which has the given ID.
	def Wmii.showClient aClientId
		`wmiir read /tags`.split.each do |view|
			Wmii.readList("/#{view}").grep(/^\d+$/).each do |column|
				Wmii.readList("/#{view}/#{column}").grep(/^\d+$/).each do |client|
					if `wmiir read /#{view}/#{column}/#{client}/index` == aClientId
						Wmii.showView view
						Wmii.write '/view/ctl', "select #{column}"
						Wmii.write "/view/sel/ctl", "select #{client}"
						return
					end
				end
			end
		end
	end

	# Changes the current view to an adjacent one (:left or :right).
	def Wmii.cycleView aTarget
		tags = `wmiir read /tags`.split

		curTag = `wmiir read /view/name`
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

		Wmii.showView newTag
	end

	# Renames the given view and sends its clients along for the ride.
	def Wmii.renameView aOld, aNew
		Wmii.readList('/client').each do |id|
			tags = `wmiir read /client/#{id}/tags`

			Wmii.write "/client/#{id}/tags", tags.gsub(aOld, aNew).squeeze('+')
		end
	end

	# Returns a list of program names available in the given paths.
	def Wmii.findPrograms *aPaths
		list = []

		Find.find(*aPaths) do |f|
			if File.executable?(f) && !File.directory?(f)
				list << File.basename(f)
			end
		end

		list.uniq.sort
	end
end
