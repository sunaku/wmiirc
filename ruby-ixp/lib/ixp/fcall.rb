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
class Hash
  alias :key :index
end

module IXP
  FCALL_IDS = {}

  class Fcall
    # Field access
    def self.add_field(name, type)
      self.fields << [name, type]
    end
    def self.fields
      # Default fields
      @fields = [[:id, 'C'], [:tag, 'S']] unless defined? @fields
			@fields
    end

    # Binary deserialization
    def self.from_b(buf)
      klass = nil
      id, = buf.unpack('C')

      klass = FCALL_IDS.key(id)
      raise "Unknown id #{id.inspect}" unless klass

      f = klass.new
      (klass.fields || []).each { |name,type|
        offset = 0

        if type =~ /^String/
          if type =~ /4$/
            length, = buf.unpack('I')
            buf = buf[4..-1]
          else
            length, = buf.unpack('S')
            buf = buf[2..-1]
          end
          f.fields[name], = buf.unpack("a#{length}")
          offset += length
        else
          f.fields[name], = buf.unpack(type)
          case type
            when /^a(\d+)$/
              offset += $1.to_i
            when 'C'
              offset += 1
            when 'S'
              offset += 2
            when 'I'
              offset += 4
            when 'Q'
              offset += 8
            else
              raise "Unsupport type #{type}"
          end
        end

        buf = buf[offset..-1]
      }

      f
    end

    # Binary serialization
    def to_b
      self.class.fields.collect { |name,type|
        case type
          when /^String4?$/
            [@fields[name].size, @fields[name]].pack("#{(type == 'String4') ? 'I' : 'S'}a#{@fields[name].size}")
          when 'Strings'
            strings = @fields[name]
            ([strings.size] + strings.collect{|s|[s.size, s]}).flatten.pack("S" + strings.collect{|s|"Sa#{s.size}"}.to_s)
          else
            [@fields[name]].pack(type)
        end
      }.to_s
    end

    # Instance initialization
    attr_reader :fields
    def initialize(fields={})
      id = FCALL_IDS[self.class]
      @fields = {:id=>id}.merge(fields)
    end
  end

  ##
  # http://v9fs.sourceforge.net/rfc/
  ##

  # version negotiate protocol

  class Tversion < Fcall
    FCALL_IDS[Tversion] = 100
    add_field :msize, 'I'
    add_field :version, 'String'
  end
  class Rversion < Fcall
    FCALL_IDS[Rversion] = 101
    add_field :msize, 'I'
    add_field :version, 'String'
  end

  # messages to establish a connection

  class Tattach < Fcall
    FCALL_IDS[Tattach] = 104
    add_field :fid, 'I'
    add_field :afid, 'I'
    add_field :uname, 'String'
    add_field :aname, 'String'
  end
  class Rattach < Fcall
    FCALL_IDS[Rattach] = 105
    add_field :qid_type, 'C'
    add_field :qid_version, 'I'
    add_field :qid_path, 'a8'
  end

  # error message

  class Rerror < Fcall
    FCALL_IDS[Rerror] = 107
    add_field :ename, 'String'
  end

  # descend a directory hierarchy

  class Twalk < Fcall
    FCALL_IDS[Twalk] = 110
    add_field :fid, 'I'
    add_field :newfid, 'I'
    add_field :nwname, 'Strings'
  end
  class Rwalk < Fcall
    FCALL_IDS[Rwalk] = 111
    add_field :nwqid, 'S'
  end

  # prepare a fid for I/O on an existing file
  class Topen < Fcall
    FCALL_IDS[Topen] = 112
    add_field :fid, 'I'
    add_field :mode, 'C'
  end
  class Ropen < Fcall
    FCALL_IDS[Ropen] = 113
    add_field :qid_type, 'C'
    add_field :qid_version, 'I'
    add_field :qid_path, 'a8'
    add_field :iounit, 'I'
  end

  # create a directory
  # size[4] Tcreate tag[2] fid[4] name[s] perm[4] mode[1]
  # size[4] Rcreate tag[2] qid[13] iounit[4]

  class Tcreate < Fcall
    FCALL_IDS[Tcreate] = 114
    add_field :fid, 'I'
    add_field :name, 'String'
    add_field :perm, 'I'
    add_field :mode, 'C'
  end
  class Rcreate < Fcall
    FCALL_IDS[Rcreate] = 115
    add_field :qid_type, 'C'
    add_field :qid_version, 'I'
    add_field :qid_path, 'a8'
    add_field :iounit, 'I'
  end


  # read, write - transfer data from and to a file
  # size[4] Tread tag[2] fid[4] offset[8] count[4]
  # size[4] Rread tag[2] count[4] data[count]
  # size[4] Twrite tag[2] fid[4] offset[8] count[4] data[count]
  # size[4] Rwrite tag[2] count[4]

  class Tread < Fcall
    FCALL_IDS[Tread] = 116
    add_field :fid, 'I'
    add_field :offset, 'Q'
    add_field :count, 'I'
  end
  class Rread < Fcall
    FCALL_IDS[Rread] = 117
    add_field :data, 'String4'
  end

  class Twrite < Fcall
    FCALL_IDS[Twrite] = 118
    add_field :fid, 'I'
    add_field :offset, 'Q'
    add_field :data, 'String4'
  end
  class Rwrite < Fcall
    FCALL_IDS[Rwrite] = 119
    add_field :count, 'I'
  end

  # fid clunking

  class Tclunk < Fcall
    FCALL_IDS[Tclunk] = 120
    add_field :fid, 'I'
  end
  class Rclunk < Fcall
    FCALL_IDS[Rclunk] = 121
  end

  # remove a file
  class Tremove < Fcall
    FCALL_IDS[Tremove] = 122
    add_field :fid, 'I'
  end
  class Rremove < Fcall
    FCALL_IDS[Rremove] = 123
  end
end
