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

$:.unshift File::dirname(__FILE__) + '/../lib'
require 'ixp'


if ARGV.size != 2
  puts "Usage: #{$0} {read|write|create|remove} <path>"
  exit
end

cmd, path = ARGV
c = IXP::Client.new

case cmd
  when 'read'
    c.open(path) { |f|
      if f.kind_of? IXP::Directory
        ents = []
        while ent = f.next
          ents << ent
        end
        ents.sort { |a,b| a.name <=> b.name }.each { |ent|
          puts '%s %s %s %5u %s %s' %
            [ent.mode_str, ent.uid, ent.gid,
             ent.length, Time.at(ent.mtime).ctime, ent.name]
        }
      else
        while buf = f.read
          print buf
        end
      end
    }
  when 'write'
    c.open(path) { |f|
      while buf = $stdin.gets
        f.write(buf)
      end
    }
  when 'create'
    c.create(path)
  when 'remove'
    c.remove(path)
  else
    puts "Error: unknown command #{cmd}"
end
