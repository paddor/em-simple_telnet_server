require_relative "test_helper"
require_relative "test_logger"

describe FakeMachine do
  let(:hostname) { "localhost" }
  let(:username) { "fakeuser" }
  let(:password) { "fakepass" }
  let(:connect_options) {
    {
      host: "localhost",
      port: 10023,

      username: username,
      password: password,

      prompt: /^fake\$ \z/,
      login_prompt: /^fakelogin: \z/,
      password_prompt: /^fakepassword: \z/,

      timeout: 2,
      login_timeout: 1,

      output_log: "output.log",
      logger_class: TestLogger,

      bin_mode: 3,
    }
  }

  def on_fake
    SimpleTelnet::Connection.new(connect_options) do |host|
      yield host
    end
  end

  it "logs in" do
    on_fake { |h| refute_nil h }
  end

  describe "with fakeroot user" do
    let(:username) { "fakeroot" }
    let(:password) { "fakerootpass" }
    it "logs in" do
      on_fake { |h| refute_nil h }
    end
  end

  describe "#on_authorization" do
    it "welcomes us" do
      on_fake do |h|
        assert_match /Hello #{username}/, h.output_logger.to_s
      end
    end
  end

  describe "echo" do
    it "sends string back" do
      on_fake do |h|
        out = h.cmd("echo foobar")
        assert_match /foobar\n/, out
      end
    end
  end

  describe "when sending LF" do
    it "sends command prompt" do
      on_fake do |h|
        out = h.cmd("")
        assert_match /fake\$ \z/, out
      end
    end
  end

  describe "count up" do
    describe "with no step argument" do
      it "counts up one by one" do
        on_fake do |h|
          h.cmd("count up") # 1
          h.cmd("count up") # 2
          out = h.cmd("count up") # 3
          assert_equal 3, out[/new number is (\d+)/, 1].to_i
        end
      end
    end
    describe "with step argument" do
      let(:step) { 5 }
      it "counts up step by step" do
        on_fake do |h|
          h.cmd("count up #{step}") # 5
          h.cmd("count up #{step}") # 10
          out = h.cmd("count up #{step}") # 15
          assert_equal 15, out[/new number is (\d+)/, 1].to_i
        end
      end
    end
  end

  describe "when asked for weird prompt" do
    it "sends weird prompt" do
      on_fake do |h|
        out = h.cmd("weird", prompt: "weird-prompt| ")
        assert_match /some\noutput\nweird-prompt\| \z/, out
      end
    end
  end

  describe "when sent logout" do
    it "closes connection" do
      before = Time.now
      assert_raises(Timeout::Error) do
        on_fake { |h| h.cmd("bye", timeout: 0.1) }
      end
      after = Time.now
      assert_in_delta after - before, 0.1, 0.1
    end
  end

  describe "when sent foo" do
    it "sends bar" do
      on_fake do |h|
        assert_equal "bar", h.cmd("foo").lines.first.chomp
      end
    end
  end
end
