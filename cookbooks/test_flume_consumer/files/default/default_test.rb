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

  it "should not have rmLibs" do
    file("/opt/flume/first_agent/lib/lucene-spatial-4.3.0.jar").wont_exist
    file("/opt/flume/first_agent/lib/lucene-suggest-4.3.0.jar").wont_exist
    # Make sure not EVERYTHING got deleted
    file("/opt/flume/first_agent/lib/metrics-core-3.0.0.jar").must_exist
  end
end