# Adds functionality for simple authentication and authorization.
#
# By default, login credentials are defined right in the class definition
# using {ClassMethods::has_login}. If something more dynamic is needed, just
# override {#authenticate}.
#
# After authentication, {#entered_username}, {#entered_password}, and
# {#authorized_role} are set.
module SimpleTelnetServer::HasLogin
  # Extends klass with {ClassMethods}.
  def self.included(klass)
    klass.extend ClassMethods
  end

  module ClassMethods

    # @return [Hash{login_type Symbol => Array<(username String, password
    #   String)>}] registered (read/write) login credentials
    def login_credentials
      options[:login_credentials] ||= {}
    end

    # Adds a pair of login credentials.
    # @param username [String] username
    # @param password [String] password
    # @param role [Symbol] (:user) the associated role name
    def has_login(username, password, role: :user)
      login_credentials[role] = [ username, password ]
    end
  end

  # @return [String] the entered username
  # @note This doesn't necessarily mean the user is logged in. Use
  #   {#authorized?} to check for that.
  attr_reader :entered_username

  # @return [String] the password username
  attr_reader :entered_password

  # @return [Symbol] the associated role of the valid login credentials
  attr_reader :authorized_role

  # @return [true] true, as this module is about authentication
  def needs_authentication?
    true
  end

  # Initiates authentication. This means setting the connection state to
  # +waiting_for_username+ and sending the login prompt.
  def initiate_authentication
    @connection_state = :waiting_for_username
    send_login_prompt
  end

  # If the user was requested to enter his username, the username is read.
  # If the user was requested to enter his password, the password is read.
  #
  # Otherwise, the normal (+super+) behavior proceeds.
  #
  # In all cases, it ensures that the buffer is cleared at the end.
  #
  def process_buffer
    if waiting_for_username?
      read_username_from_buffer

    elsif waiting_for_password?
      read_password_from_buffer

    else
      super
    end
  ensure
    @buffer.clear
  end

  # Sends the login prompt.
  def send_login_prompt
    send_data options[:login_prompt]
  end

  # Sends the password prompt.
  def send_password_prompt
    send_data options[:password_prompt]
  end

  # @return [Boolean] whether we are waiting for the user to enter the username
  def waiting_for_username?
    @connection_state == :waiting_for_username
  end

  # @return [Boolean] whether we are waiting for the user to enter the password
  def waiting_for_password?
    @connection_state == :waiting_for_password
  end

  # Reads the password from buffer and authorizes the user
  # if he can be authenticated. Otherwise the
  # connection state is set back to +:waiting_for_username+ and the login
  # prompt is sent.
  def read_password_from_buffer
    @entered_password = @buffer.chomp
    if role = authenticate(@entered_username, @entered_password)
      @authorized_role = role
      authorize
    else
      @connection_state = :waiting_for_username
      @entered_username = @entered_password = nil
      send_login_failed
      send_login_prompt
    end
  end

  # Reads the username from buffer. Sends the password prompt
  # afterwards ({#send_password_prompt}) and sets the connection state to
  # +:waiting_for_password+.
  def read_username_from_buffer
    @entered_username = @buffer.strip
    send_password_prompt
    @connection_state = :waiting_for_password
  end

  # Sends the message "Sorry, please try again." and the login prompt.
  def send_login_failed
    send_data "Sorry, please try again.\n"
  end


  # Checks _user_ and _pass_ against all known login credentials.
  #
  # @param user [String] entered username
  # @param pass [String] entered password
  # @return [Symbol] associated role, if credentials are known
  # @return [nil] if credentials are not known
  def authenticate(user, pass)
    self.class.login_credentials.each do |role, credentials|
      return role if credentials == [ user, pass ]
    end
    return nil
  end
end
