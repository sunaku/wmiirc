=begin
Ruby-IXP, Copyright 2006 Stephan Maka

This file is part of Ruby-IXP.

Ruby-IXP is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

Ruby-IXP is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Ruby-IXP; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA)
=end
require 'ixp'

class WMII
  def initialize
    begin
      @cl = IXP::Client.new
    rescue Errno::ECONNREFUSED
      retry
    end
    @key_blocks = []
    @barclick_blocks = []
  end

  def create(file)
    @cl.create(file)
  rescue IXP::IXPException => e
    puts "#{e.backtrace.first}: #{e}"
  end

  def read(file)
    @cl.open(file) do |f|
      if f.respond_to? :next
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

  def remove(file)
    @cl.remove(file)
  rescue IXP::IXPException => e
    puts "#{e.backtrace.first}: #{e}"
  end

  def write(file, data)
    @cl.open(file) { |f| f.write(data.to_s) }
  rescue IXP::IXPException => e
    puts "#{e.backtrace.first}: #{e}"
  end

  def menu(choices)
    r = IO::popen("wmiimenu", "r+") {|io| io.puts choices.join("\n"); io.close_write; io.readlines.to_s }
    r.size > 0 ? r : nil
  end

  def env_selcolors=(font_face_border)
    ENV['WMII_SELCOLORS'] = font_face_border
  end

  def env_normcolors=(font_face_border)
    ENV['WMII_NORMCOLORS'] = font_face_border
  end

  def env_font=(name)
    ENV['WMII_FONT'] = name
  end

  def event_loop
    @cl.open('/event') { |f|
      while line = f.read
        event, args = line.chomp.split(' ', 2)

        case event
          when 'Start'
            return if args == 'wmiirc'
          when 'Key'
            @key_blocks.each { |sym,block|
              if sym == args
                block.call
              end
            }
          when 'BarClick'
            bar_name, btn = args.split(' ', 2)
            @barclick_blocks.each { |bar,block|
              if bar == bar_name
                block.call(btn)
              end
            }
        end
      end
    }
  end

  class Bar
    def initialize(wmii, name)
      @wmii = wmii
      @name = name
      @colors = nil
    end

    def path
      "/bar/#{@name}"
    end

    def colors
      unless @colors
        @colors = @wmii.read("#{path}/colors")
      end
      @colors
    end

    def colors=(font_face_border)
      if font_face_border != @colors
        @wmii.write("#{path}/colors", font_face_border)
        @colors = nil
      end
    end

    def data=(data)
      @wmii.write("#{path}/data", data)
    end

    def periodic(interval=1, &updater)
      Thread.new do
        old_data = nil
        loop {
          data = updater.call
          if data != old_data
            self.data = data
            old_data = data
          end
          sleep interval
        }
      end
    end
  end

  def new_bar(name)
    bar = Bar.new(self, name)
    create bar.path
    bar
  end

  def go_view(view)
    write('/ctl', "view #{view}")
  end

  def write_keys
    write "/def/keys", @key_blocks.collect { |sym,block|
      sym
    }.join("\n") + "\n"
  end

  def on_key(sym, &block)
    @key_blocks << [sym, block]
    write_keys
  end

  def on_barclick(bar, &block)
    @barclick_blocks << [bar, block]
  end

  def border=(width)
    write '/def/border', width.to_s
  end

  def selcolors=(font_face_border)
    write '/def/selcolors', font_face_border
  end

  def normcolors=(font_face_border)
    write '/def/normcolors', font_face_border
  end

  def font=(name)
    write '/def/font', name
  end
end
