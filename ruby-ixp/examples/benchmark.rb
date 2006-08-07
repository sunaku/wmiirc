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

require 'benchmark'
begin
  require 'rubygems'
rescue LoadError
  $: << '/usr/local/lib/ruby/gems/1.8/gems/rstyx-0.2.0/lib/'
end
require 'rstyx'


FILE = '/def/rules'
N = 1000

def do_ruby_ixp(c)
  c.open(FILE) { |f| f.read_all }
end

def do_wmiir
  IO::popen("wmiir read #{FILE}") { |io| io.readlines.to_s }
end

module RStyx
  module Client
    class UNIXConnection < Connection
      def initialize(path, user='')
        @path = path
        super(user)
      end
      def startconn
        UNIXSocket.new(@path)
      end
    end
  end
end

def do_rstyx(c)
  c.open(FILE) { |f| f.read }
end

ruby_ixp_client = IXP::Client.new
rstyx_client = RStyx::Client::UNIXConnection.new(ENV['WMII_ADDRESS'].gsub(/^unix!/, ''))


Benchmark::bmbm(10) do |b|
  b.report('ruby_ixp:') { N.times { do_ruby_ixp(ruby_ixp_client) } }
  b.report('wmiir:') { N.times { do_wmiir } }
  b.report('rstyx:') { N.times { do_rstyx(rstyx_client) } }
end

