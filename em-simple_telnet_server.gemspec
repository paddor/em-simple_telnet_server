# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'em-simple_telnet_server/version'

Gem::Specification.new do |spec|
  spec.name          = "em-simple_telnet_server"
  spec.version       = SimpleTelnetServer::VERSION
  spec.authors       = ["Patrik Wenger"]
  spec.email         = ["paddor@gmail.com"]

  spec.summary       = "Simple telnet server on EventMachine"
  spec.description   = "A simple way to implement your own telnet server on" +
                       " EventMachine"
  spec.homepage      = "http://github.com/paddor/em-simple_telnet_server"
  spec.license       = "ISC"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency 'minitest-reporters'
  spec.add_dependency('eventmachine', '>= 1.0.0')
end
