#!/usr/bin/env ruby

$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'wmiirc/loader'
Wmiirc::Loader.run
