$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'em-simple_telnet_server'
require_relative 'fake_machine_starter' # forks and starts server
require_relative 'fake_machine'

require 'bundler/setup'
require 'em-simple_telnet'


require 'minitest/spec'
require 'minitest/autorun'
require "minitest/reporters"
Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new()]
