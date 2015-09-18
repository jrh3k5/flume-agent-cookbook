flume_user = "flume"
flume_user_group = "flume"

# Install the first Flume agent
flume_agent "first_agent" do
  action :create
  userName flume_user
  userGroup flume_user_group
  agentName "first_agent"

  rmLib "lucene-spatial-4.3.0.jar"
  rmLib "lucene-suggest-4.3.0.jar"
  # Test that the resource tolerates non-existent libraries
  rmLib "doesntexistbutthatsokay.jar"

  postStartupScript do
    cookbook_filename "test_startup_hook.sh.erb"
    variables("attributes" => { "instanceName" => "first_agent" })
  end

  configFile do
    cookbook_filename "flume.first.properties.erb"
    cookbook "test_flume_consumer"
  end
end

# Install the second Flume agent
flume_agent "second_agent" do
  action :create
  userName flume_user
  userGroup flume_user_group
  agentName "second_agent"

  configFile do
    cookbook_filename "flume.second.properties.erb"
    cookbook "test_flume_consumer"
  end
end