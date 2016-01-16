require_relative 'fake_machine'
module FakeMachineStarter
  module_function

  # Forks and starts EventMachine.
  # Ensures that the new process is killed when this process exits.
  def start
    pid = fork do
      EventMachine.run do
        FakeMachine.start_server
      end
    end

    kill_at_exit(pid)

    # wait for EventMachine to get started
    sleep 0.5
  end

  # Ensures that +pid+ is killed at exit of this process.
  def kill_at_exit(pid)
    current_pid = $$
    at_exit do
      begin
        Process.kill :KILL, pid
      rescue Errno::ESRCH
        # process already dead
      end if $$ == current_pid # only in main process
    end
  end
end

FakeMachineStarter.start

