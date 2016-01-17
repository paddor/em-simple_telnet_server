[![Build Status on Travis CI](https://travis-ci.org/paddor/em-simple_telnet_server.svg?branch=master)](https://travis-ci.org/paddor/em-simple_telnet_server?branch=master)

# SimpleTelnetServer

This gem provides a simple way to implement your own telnet server. It's useful
for example if you want to mock a telnet server in your telnet-related
integration tests.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'em-simple_telnet_server'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install em-simple_telnet_server

## Usage

Here's an example, right from [test/fake_machine.rb](https://github.com/paddor/em-simple_telnet_server/blob/master/test/fake_machine.rb).

```ruby
require 'em-simple_telnet_server'

##
# This should just demonstrate what you can do with SimpleTelnetServer.
#
class FakeMachine < SimpleTelnetServer::Connection
  # adds simple authentication and authorization
  include SimpleTelnetServer::HasLogin

  has_option :command_prompt, "fake$ "
  has_option :login_prompt, "
fakelogin: "
  has_option :password_prompt, "
fakepassword: "

  has_login "fakeuser", "fakepass" # default is ":user" role
  has_login "fakeroot", "fakerootpass", role: :admin

  # Echo command.
  has_command(/^s*echo (.*)/) do |what|
    send_output(what) # this also sends a prompt back
  end

  # Send command prompt on return.
  has_command(/^s*$/, :send_command_prompt)

  # This is the callback that is called right after authorization. You could
  # initialize your code here.
  def on_authorization
    send_data "Hello #{entered_username}! You're authorized now.
"
    # NOTE: first command prompt is sent automatically after this
  end

  # Just to demonstrate the ability to use methods as command actions instead
  # of blocks. This method will be called directly if the command "count up"
  # is called.  It also supports commands in the form of "count up 5".
  #
  # See the call to {.has_command} below.
  def count_up(step=nil)
    step ||= 1
    step = Integer step
    @count_up_number ||= 0
    @count_up_number += step
    send_output "The new number is #@count_up_number."
  end
  has_command(/count up(?:s+(d+))/, :count_up)

  # Simulates a slow command which could be used to test timeouts.
  # This can be invoked using "slow command".
  def slow_command
    EventMachine::Timer.new(3) { send_output "This is the output." }
  end

  # Recognizes commands like "sleep 3" and "sleep 1.5" and actually performs
  # the sleep.
  has_command(/^sleeps+(d+(?:.d+)?)s*$/) do |seconds|
    EventMachine::Timer.new(seconds.to_f) do
      send_output "This is the output."
    end
  end

  # Simulates a command that ends in a very weird prompt.
  #
  # This is just to demonstrate the use of {#send_data}. It won't send the
  # default command prompt like {#send_output} would.
  has_command(/^weirds*$/) do
    send_data("some
output
weird-prompt| ")
  end

  # logout
  has_command(/^byes*$/, :close_connection)

  # tanslate every command to a method call, if the method exists
  # @note This is probably dangerous. But whatever, it's telnet.
  has_command(/^([w ]+)$/) do |command|
    method = command.gsub(/ /, '_')
    if self.respond_to? method
      self.send method
    else
      raise UnknownCommand, command
    end
  end

  # Simplest test command ever. This will only be invokable because of the
  # catch-all-and-translate-to-method-calls block above.
  def foo
    send_output("bar")
  end
end
```

You can run it as follows. By default, it'll start listening on "localhost" and port 10023.

```ruby
EventMachine.run do
  FakeMachine.start_server
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/paddor/em-simple_telnet_server.


## License

The gem is available as open source under the terms of the [ISC License](http://opensource.org/licenses/ISC).
See the [LICENSE](https://github.com/paddor/em-simple_telnet_server/blob/master/LICENSE) file.
