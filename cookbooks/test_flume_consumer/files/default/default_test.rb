require 'minitest/spec'
require 'chef/mixin/shell_out'

describe_recipe "test_flume_consumer::default" do
  
  include MiniTest::Chef::Assertions
  include MiniTest::Chef::Context
  include MiniTest::Chef::Resources
  include Chef::Mixin::ShellOut
  
  it "should complete deployment process without errors" do
    assert run_status.success?
  end

  it "should have expected number of services running" do
    service("flume_first_agent").must_be_running
    service("flume_second_agent").must_be_running
  end
  
  it "should install the post-startup hook" do
    # Only the first agent has a post-startup hook specified
    file("/opt/flume/first_agent/bin/first_agent_startup_hook.sh").must_exist
    # The script should have been executed
    file("/tmp/flume_first_agent").must_exist
  end
end