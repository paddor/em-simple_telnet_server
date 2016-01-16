require 'em-simple_telnet_server'

##
# This should just demonstrate what you can do with SimpleTelnetServer.
#
class FakeMachine < SimpleTelnetServer::Connection
  # adds simple authentication and authorization
  include SimpleTelnetServer::HasLogin

  has_option :command_prompt, "fake$ "
  has_option :login_prompt, "\nfakelogin: "
  has_option :password_prompt, "\nfakepassword: "

  has_login "fakeuser", "fakepass" # default is ":user" role
  has_login "fakeroot", "fakerootpass", role: :admin

  # Echo command.
  has_command(/^\s*echo (.*)/) do |what|
    send_output(what) # this also sends a prompt back
  end

  # Send command prompt on return.
  has_command(/^\s*$/, :send_command_prompt)

  # This is the callback that is called right after authorization. You could
  # initialize your code here.
  def on_authorization
    send_data "Hello #{entered_username}! You're authorized now.\n"
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
  has_command(/count up(?:\s+(\d+))/, :count_up)

  # Simulates a slow command which could be used to test timeouts.
  # This can be invoked using "slow command".
  def slow_command
    EventMachine::Timer.new(3) { send_output "This is the output." }
  end

  # Recognizes commands like "sleep 3" and "sleep 1.5" and actually performs
  # the sleep.
  has_command(/^sleep\s+(\d+(?:\.\d+)?)\s*$/) do |seconds|
    EventMachine::Timer.new(seconds.to_f) do
      send_output "This is the output."
    end
  end

  # Simulates a command that ends in a very weird prompt.
  #
  # This is just to demonstrate the use of {#send_data}. It won't send the
  # default command prompt like {#send_output} would.
  has_command(/^weird\s*$/) do
    send_data("some\noutput\nweird-prompt| ")
  end

  # logout
  has_command(/^bye\s*$/, :close_connection)

  # tanslate every command to a method call, if the method exists
  # @note This is probably dangerous. But whatever, it's telnet.
  has_command(/^([\w ]+)$/) do |command|
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
