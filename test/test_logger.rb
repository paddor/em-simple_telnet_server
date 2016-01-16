require 'logger'

class TestLogger < Logger
  def initialize(filename)
    @filename = filename
    @dev = StringIO.new
    super(@dev)
    self.level = "debug"
  end
  def to_s
    @dev.string
  end
end
