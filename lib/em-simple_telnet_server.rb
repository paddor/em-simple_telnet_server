require_relative "em-simple_telnet_server/version"
require_relative "em-simple_telnet_server/has_login"
require 'eventmachine'

# A basic Telnet server implemented with EventMachine.
class SimpleTelnetServer::Connection < EventMachine::Connection
  # @return [Hash<Symbol, Object>] default values for (telnet) options
  DEFAULT_OPTIONS = {
    port: 10023,
    command_prompt: "$ ",
    login_prompt: "login: ",
    password_prompt: "password: ",
  }

  class << self

    # Starts the server on address _addr_ and port _port_.
    def start_server(addr = 'localhost', port = options[:port])
      EventMachine.start_server(addr, port, self)
    end

    # Sets the option _opt_ to value.
    # @param opt [Symbol] option key
    # @param value [Object] anything
    def has_option(opt, value)
      options[opt] = value
    end

    # Returns the (telnet) options for this class. If they are not initialized
    # yet, the ones from superclass (or SimpleTelnetServer) are duplicated.
    def options
      @options ||= if top_class?
        DEFAULT_OPTIONS
      else
        superclass.options
      end.dup
    end

    # Registers an action for the command _cmd_ (which can be a Regexp, #===
    # will be used). _action_ can be a Symbol referring to an instance method
    # or an instance of Proc. If _action_ is not specified, the given block is
    # used.
    #
    # If _cmd_ is a Regexp, all captures (MatchData#captures) will be passed
    # to the block/method call (see {#run_command}).
    #
    # @param cmd [String, Regexp] fixed command or regular expression that
    #   matches a command and its arguments in capture groups
    # @param action [Symbol] the method to call. if given, the block passed is
    #   ignored
    def has_command(cmd, action = nil, &blk)
      commands[cmd] = action || blk
    end

    # Returns the Hash of registered commands. If they are not initialized
    # yet (@commands), the one from superclass is used. If we're TelnetServer
    # itself, an empty Hash is used.
    #
    # @return [Hash{String, Regexp => Symbol, Proc}]
    def commands
      @commands ||= if top_class?
        {}
      else
        superclass.commands.dup # copy from superclass
      end
    end

    # @return [Boolean] whether we've reached the top of the relevant
    #   hieararchy
    def top_class?
      self == SimpleTelnetServer::Connection
    end
  end

#  def send_data(data)
#    warn "Server: >>> #{data.inspect}"
#    super
#  end


  # custom handler of buffer content
  # @return [Proc, #call] will be passed the content of the buffer
  attr_accessor :custom_handler

  # Called by EventMachine when a new connection attempt is made to this
  # server (immediately after calling {#initialize}).
  #
  # Checks if {#needs_authentication?}, which returns +false+ if not
  # overridden. If it authentication is needed, it'll initiate the login
  # procedure (send login prompt, get username, get password, ...).
  #
  # Otherwise, any peer is authorized right away.
  def post_init
    @buffer = ""
    if needs_authentication?
      initiate_authentication
    else
      authorize # login anybody
    end
  end

  # @abstract
  # If authentication is not required, there won't be a login procedure and
  # any peer is automatically logged in after connecting.
  # @return [Boolean] whether this telnet server requires authentication
  def needs_authentication?
    false
  end

  # Called by EventMachine when new data is received. Appends _data_ to the
  # buffer (@buffer). Calls {#process_buffer} if @buffer content ends with
  # newline.
  def receive_data data
#    warn "Server: <<< #{data.inspect}"
    @buffer << data

    # work only with complete commands (ending with newline)
    process_buffer if @buffer.end_with? "\n"
  end

  # @return [Boolean] whether the user is logged in
  def authorized?
    @connection_state == :authorized
  end

  # @abstract
  # Called by EventMachine after the connection has been closed.
  def unbind
  end

  # @abstract
  # Called automatically when a received command is not known (no matching
  # entry in @commands) and sends back an error message.
  #
  # @param command [String] the command that is not known
  def command_not_known(command)
    send_output "Command #{command.inspect} is not known."
  end

  # Returns the telnet options for this telnet server.
  def options
    self.class.options
  end

  # Returns the recognized commands for this telnet server.
  def commands
    self.class.commands
  end

  private

  # Sends the command prompt.
  def send_command_prompt
    send_data options[:command_prompt]
  end

  # Sends _output_ and then the command prompt.
  # Appens new line to output first, if it doesn't have one yet, unless it's
  # the empty string.
  # @param output [String] output to send before command prompt
  def send_output(output)
    output += "\n" unless output.end_with? "\n" or output.empty?
    send_data output
    send_command_prompt
  end

  # Processes the content of @buffer.
  #
  # If a {#custom_handler} is defined, it's called with the current buffer
  # contents. The handler will be removed, so if it has to stay, it has to
  # re-add itself.
  #
  # If the user is authorized, the commands in the buffer are executed.
  #
  # If the user isn't authorized, {#process_spam} is called, which does
  # nothing by default.
  #
  # Ensures that the buffer is cleared.
  def process_buffer
    if handler = custom_handler
      self.custom_handler = nil
      handler.(@buffer)

    elsif authorized?
      run_commands
    else
      process_spam
    end
  ensure
    @buffer.clear
  end

  # Authorizes the user. This is done by setting @connection_state to
  # +:authorized+, calling the {#on_authorization} hook method, and sendng him
  # the command prompt.
  def authorize
    @connection_state = :authorized
    on_authorization
    send_command_prompt
  end

  # @abstract
  # Called right after authorization. You can override this method to
  # initialize your code.
  #
  # Using {#initialize} instead is a bit clunky because it's expected to take
  # EventMachine-specific arguments and happens before the user is authorized.
  # Same goes for {#post_init}. For both you'd have to remember to call
  # +super+.
  def on_authorization
  end

  # Raised when a command has been received that doesn't match any registered
  # command.
  class UnknownCommand < RuntimeError
    def initialize(command) @command = command end
    attr_reader :command
  end

  # Runs the commands in the buffer. Will call {#run_command} for each command
  # (line), no matter if it is recognized or not. If {UnknownCommand} is
  # raised, it's handled using {#command_not_known}.
  def run_commands
    @buffer.lines.each do |command|
      run_command(command.chomp)
    end
  rescue UnknownCommand
    command_not_known $!.command
  end

  # Runs a command.
  #
  # Stores _command_ into @current_command for later use and looks it up. If
  # it finds an action for it, executes the action.
  #
  # If the matching command pattern is a Regexp, the captures are passed to
  # the action.
  #
  # @param command [String] command to run
  # @raise [UnknownCommand] if the command is unknown
  def run_command(command)
    @current_command = command
    if pair = commands.find { |pattern,| pattern === command }
      pattern, action = pair
      args = $~.captures if pattern.is_a? Regexp
      execute_action(action, args) if action
    else
      raise UnknownCommand, command
    end
  end

  # Invokes _action_ along with the given arguments.
  #
  # @param action [Proc, Symbol] code or a method on this server to call
  # @param params [Array<Object>, nil] arguments for action (passed with splat
  #   operator)
  # @raise [ArgumentError] if action is invalid
  def execute_action(action, args = nil)
    case action
    when Proc
      self.instance_exec(*args, &action)
    when Symbol
      self.send(action, *args)
    else
      raise ArgumentError, "invalid action #{action.inspect}"
    end
  end

  # @abstract
  # Called when data has been received while user isn't authorized. This could
  # be used to {#close_connection}.
  def process_spam
  end
end
