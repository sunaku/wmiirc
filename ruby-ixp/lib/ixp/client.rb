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
require 'socket'
require 'thread'

require 'ixp/fcall'

module IXP
  class IXPException < RuntimeError
  end

  class Connection
    def initialize(path)
      @sock = UNIXSocket.new(path)

      @send_blocks = {}
      @send_blocks_lock = Mutex.new
      Thread.abort_on_exception = true
      Thread.new {
        parser
      }
    end

    def gen_tag
      @send_blocks_lock.synchronize {
        begin
          tag = rand(2 ** 16)
        end while @send_blocks.has_key? tag

        tag
      }
    end

    def send(fcall)
      fcall.fields[:tag] = gen_tag unless fcall.fields[:tag]
      buf = fcall.to_b
      id, tag = buf.unpack('cS')
      #puts "Sending #{([buf.size + 6].pack('I') + buf).inspect}"

      @send_blocks_lock.synchronize {
        @send_blocks[tag] = Thread.current
      }

      begin
        @sock.write([buf.size + 4].pack('I') + buf)

        Thread.stop
      rescue FcallResult => result
        if result.fcall.kind_of? Rerror
          raise IXPException.new(result.fcall.fields[:ename])
        else
          result.fcall
        end
      end
    end

    def parser
      while buf = @sock.read(4)
        len, = buf.unpack('I')
        buf = @sock.read(len - 4)
        id, tag = buf.unpack('cS')

        @send_blocks_lock.synchronize {
          if @send_blocks.has_key? tag
            @send_blocks[tag].raise FcallResult.new(Fcall::from_b(buf))
            @send_blocks.delete tag
          else
            puts "Unexpected packet with tag #{tag.inspect}"
          end
        }
      end
    end
  end

  class Client < Connection
    def initialize(path=ENV['WMII_ADDRESS'])
      raise 'Nowhere to connect' unless path

      super(path.gsub(/^unix!/, ''))
      @last_fid = -1

      rv = send(Tversion.new(:tag=>0, :version=>'9P2000', :msize=>8192))
      if rv.fields[:version] != '9P2000'
        raise "Unknown 9P version: #{rv.version.inspect}"
      end

      @root_fid = gen_fid
      send(Tattach.new(:tag=>0, :fid=>@root_fid, :afid=>0, :uname=>ENV['USER'], :aname=>''))
    end

    def gen_fid
      @last_fid += 1
    end

    # result:: [Fixnum] newfid
    def walk(filepath)
      fid = gen_fid
      send Twalk.new(:fid=>@root_fid, :newfid=>fid, :nwname=>filepath.sub(/^\//, '').split('/'))
      fid
    end

    # modes
    OREAD = 0x00
    OWRITE = 0x01
    ORDWR = 0x02
    OEXEC = 0x03
    OEXCL = 0x04
    OTRUNC = 0x10
    OREXEC = 0x20
    ORCLOSE = 0x40
    OAPPEND = 0x80
    # qid_type
    QTDIR = 0x80
    def open(filepath, mode=OREAD)
      fid = walk(filepath)
      ro = send(Topen.new(:fid=>fid, :mode=>mode))
      f = ((ro.fields[:qid_type] == QTDIR) ? Directory : File).new(self, fid, ro.fields[:iounit])

      if block_given?
        begin
          yield f
        ensure
          f.close
        end
      else
        f
      end
    end

    DMWRITE = 0x80
    def create(filepath, perm=DMWRITE, mode=OWRITE)
      path = filepath.split('/')

      fid = walk(path[0..-2].join('/'))
      send Tcreate.new(
                       :fid=>fid,
                       :name=>path.last,
                       :perm=>perm,
                       :mode=>mode
                      )
      send Tclunk.new(:fid=>fid)
    end

    def remove(filepath)
      fid = walk(filepath)
      send Tremove.new(:fid=>fid)
      # No clunking needed
    end
  end

  class File
    def initialize(client, fid, iounit)
      @client = client
      @fid = fid
      @iounit = iounit
      @pos = 0
    end

    def read
      rr = @client.send(Tread.new(
                                  :fid=>@fid,
                                  :offset=>@pos,
                                  :count=>@iounit
                                 ))
      data = rr.fields[:data]
      @pos += data.size
      (data.size > 0) ? data : nil
    end

    def read_all
      all = ''
      while chunk = read
        all << chunk
      end
      all
    end

    def write(buf_)
      buf = buf_
      while buf.size > @iounit
        write buf[0..(@iounit-1)]
        buf = buf[@iounit..-1]
      end

      rw = @client.send(Twrite.new(
                                   :fid=>@fid,
                                   :offset=>@pos,
                                   :data=>buf
                                  ))
      @pos += rw.fields[:count]
      rw.fields[:count]
    end

    def close
      @client.send Tclunk.new(:fid=>@fid)
    end
  end

  class Directory < File
    def initialize(client, fid, iounit)
      super
      @buf = nil
    end

    def next
      @buf = read_all unless @buf

      if @buf.size < 2
        nil
      else
        stat = Stat.new(@buf)
        @buf = @buf[(stat.size+2)..-1]
        stat
      end
    end
  end

  # size[2]
  #     total byte count of the following data
  # type[2]
  #     for kernel use
  # dev[4]
  #     for kernel use
  # qid.type[1]
  #     the type of the file (directory, etc.), represented as a bit vector corresponding to the high 8 bits of the file's mode word.
  # qid.vers[4]
  #     version number for given path
  # qid.path[8]
  #     the file server's unique identification for the file
  # mode[4]
  #     permissions and flags
  # atime[4]
  #     last access time
  # mtime[4]
  #     last modification time
  # length[8]
  #     length of file in bytes
  # name[ s ]
  #     file name; must be / if the file is the root directory of the server
  # uid[ s ]
  #     owner name
  # gid[ s ]
  #     group name
  # muid[ s ]
  #     name of the user who last modified the file
  class Stat
    attr_reader :size, :type, :dev, :qid_type, :qid_version, :qid_path, :mode, :atime, :mtime, :length, :name, :uid, :gid, :muid
    def initialize(buf_)
      buf = buf_

      @size, @type, @dev, @qid_type, @qid_version, @qid_path, @mode, @atime, @mtime, @length = buf.unpack('SSICIa8IIIQ')
      buf = buf[(2+2+4+1+4+8+4+4+4+8)..-1]

      name_size, = buf.unpack('S')
      buf = buf[2..-1]
      @name, = buf.unpack("a#{name_size}")
      buf = buf[name_size..-1]

      uid_size, = buf.unpack('S')
      buf = buf[2..-1]
      @uid, = buf.unpack("a#{uid_size}")
      buf = buf[uid_size..-1]

      gid_size, = buf.unpack('S')
      buf = buf[2..-1]
      @gid, = buf.unpack("a#{gid_size}")
      buf = buf[gid_size..-1]

      muid_size, = buf.unpack('S')
      buf = buf[2..-1]
      @muid, = buf.unpack("a#{muid_size}")
      buf = buf[muid_size..-1]
    end

    def mode_str
      modes = %w(--- --x -w- -wx r-- r-x rw- rwx)

      ((@mode & 0x80000000 != 0) ? 'd' : '-') +
        '-' +
        modes[(mode >> 6) & 7] +
        modes[(mode >> 3) & 7] +
        modes[mode & 7]
    end
  end

  class FcallResult < Exception
    attr_reader :fcall
    def initialize(fcall)
      @fcall = fcall
    end
  end
end

