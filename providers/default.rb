require 'fileutils'
require 'uri'

@@VALID_FLUME_URI_REGEX = Regexp.new "apache-flume-\\d+\\.\\d+(\\.\\d+)*-bin\\.tar\\.gz$"

action :create do
  attributes = Hash.new
  
  attributes["userGroup"] = new_resource.userGroup
  attributes["userName"] = new_resource.userName
  attributes["instanceName"] = new_resource.agentName
  attributes["plugins"] = new_resource.flumePlugins
  attributes["agentConfigFile"] = new_resource.agentConfigFile
  attributes["loggingProperties"] = new_resource.loggingProps
  attributes["flumeEnv"] = new_resource.flumeEnvSh
  attributes["jmxProps"] = new_resource.jmxProps
  attributes["serviceName"] = "flume_#{attributes["instanceName"]}"
  attributes["baseDir"] = node["flume"]["baseDir"]
  attributes["installDir"] = "#{attributes["baseDir"]}/#{attributes["instanceName"]}"
  attributes["flumeConfDir"] = "#{attributes["installDir"]}/conf"
  attributes["outputConfigurationFile"] = "#{attributes["flumeConfDir"]}/flume.agent.#{attributes["instanceName"]}.properties"
  attributes["postStartupScript"] = new_resource.agentPostStartupScript
  attributes["rmLibs"] = new_resource.rmLibs

  if !ENV["JAVA_HOME"]
    raise Exception.new("JAVA_HOME environment variable not found - has Java been previously installed?")
  end
  
  # Read the Flume metadata (or initialize it if it exists)
  flumeMetadata = readFlumeMetadata attributes["installDir"]
  if !flumeMetadata
    flumeMetadata = Hash.new
  end

  #Ensure Flume group and user have been setup
  group attributes["userGroup"] do
    action :create
  end

  user attributes["userName"] do
    gid attributes["userGroup"]
  end

  # Add the Flume agent as a service
  template "/etc/init.d/#{attributes["serviceName"]}" do
    source "flume-agent.sh.erb"
    cookbook "flume_agent"
    mode "0755"
    variables(:attributes => attributes)
    backup false
  end

  tarUri = node["flume"]["archiveUrl"]
  tarUriPath = URI.parse(tarUri).path.split("/").last
  tarFilename = getNameOfTarFileFromURI(@@VALID_FLUME_URI_REGEX, tarUriPath)
  if !tarFilename
    raise Exception.new("Unable to retrieve Flume TAR filename from URI #{tarUri} and path #{tarUriPath}")
  end

  remote_file "#{Chef::Config[:file_cache_path]}/#{tarFilename}" do
    action :create_if_missing
    source tarUri
    group attributes["userGroup"]
    owner attributes["userName"]
    mode "0755"
    backup false
  end

  # Make sure the base directory exists
  directory attributes["baseDir"] do
    action :create
      owner attributes["userName"]
      group attributes["userGroup"]
      mode "0700"
      recursive true
  end

  tarBasename = ::File.basename(tarFilename, ".tar.gz")

  # If there is a new version of Flume being installed, then delete the old installation
  if tarBasename != flumeMetadata["flume_version"]
    directory attributes["installDir"] do
      action :delete
      recursive true
    end
  end
  flumeMetadata["flume_version"] = tarBasename
  
  # Make sure that the installation directory exists and has sufficient privileges
  directory attributes["installDir"] do
    action :create
      owner attributes["userName"]
      group attributes["userGroup"]
      mode "0700"
      recursive true
  end
  
  # Install Flume
  bash "Unpack Flume Agent #{attributes["instanceName"]} to #{attributes["installDir"]}" do
    user "root"
    cwd attributes["baseDir"]

    # Untar the archive and then move it to the final location
    code <<-EOH
     tar zxf #{Chef::Config[:file_cache_path]}/#{tarFilename}
     mv #{tarBasename}/* #{attributes["installDir"]}
     rm -rf #{tarBasename}
    EOH

    returns [0]

    # We're about to deploy a potentially new configuration
    # Flume will attempt to dynamically cycle the agent while we are restarting it, and this can cause issues
    notifies :stop, "service[#{attributes["serviceName"]}]", :immediately
  end

  attributes["rmLibs"].each do |rmLib|
    ruby_block "Delete #{rmLib}" do
      block do
        fullFilename = "#{attributes["installDir"]}/lib/#{rmLib}"
        if ::File.exist?(fullFilename) 
          ::File.delete(fullFilename)
        end
      end
    end
  end
  
  # Make sure the appropriate user owns the Flume installation
  execute "Make #{attributes["userName"]}:#{attributes["userGroup"]} owner of #{attributes["installDir"]}" do
    command "chown -Rf #{attributes["userName"]}:#{attributes["userGroup"]} #{attributes["installDir"]}"
  end

  # If a Flume environment shell script is provided, install that
  agentShellScript = ::File.join(attributes["flumeConfDir"], "flume-env-#{attributes["instanceName"]}.sh")
  if attributes["flumeEnv"]
    template agentShellScript do
      action :create
      source attributes["flumeEnv"]["cookbook_filename"]
      cookbook attributes["flumeEnv"]["cookbook"] ? attributes["flumeEnv"]["cookbook"] : new_resource.cookbook_name.to_s
      owner attributes["userName"]
      group attributes["userGroup"]
      mode "0700"
      variables(attributes["flumeEnv"]["variables"])
      backup false
    end
  end

  template ::File.join(attributes["flumeConfDir"], "flume-env.sh") do
    action :create
    source "flume-env.sh.erb"
    cookbook "flume_agent"
    owner attributes["userName"]
    group attributes["userGroup"]
    mode "0700"
    variables(:agentShellScript => agentShellScript, :jmxProps => attributes["jmxProps"])
    backup false
  end

  configFileVars = nil
  # If the consumer provides 'variables' apply them to the hash 
  if !attributes["agentConfigFile"]["variables"].nil?
    configFileVars = attributes["agentConfigFile"]["variables"]
  else
    configFileVars = Hash.new
  end

  # Install the configuration file
  template attributes["outputConfigurationFile"] do
    action :create
    source attributes["agentConfigFile"]["cookbook_filename"]
    cookbook attributes["agentConfigFile"]["cookbook"] ? attributes["agentConfigFile"]["cookbook"] : new_resource.cookbook_name.to_s
    owner attributes["userName"]
    group attributes["userGroup"]
    mode "0700"
    variables(configFileVars)
    backup false
    sensitive true
  end
  
  # Install the logging properties (if provided)
  if attributes["loggingProperties"]
    loggingProperties = attributes["loggingProperties"]
    template ::File.join(attributes["installDir"], "conf", "log4j.properties") do
      source loggingProperties["cookbook_filename"]
      cookbook loggingProperties["cookbook"] ? loggingProperties["cookbook"] : new_resource.cookbook_name.to_s
      mode "0755"
      variables(loggingProperties["variables"])
      backup false
    end
  end

  # Install plugins
  if !attributes["plugins"].empty?
    pluginsDir = ::File.join(attributes["installDir"], "plugins.d")
    FileUtils.mkdir_p pluginsDir
    # Make sure the plugins directory exists
    directory pluginsDir do
      action :create
        owner attributes["userName"]
        group attributes["userGroup"]
        mode "0700"
        recursive true
    end
    
    # Install each plugin
    attributes["plugins"].keys.each do |pluginName|
      pluginInfo = attributes["plugins"][pluginName]
      pluginTarName = nil
      pluginTarLocation = nil
      if pluginInfo["cookbook_filename"]
        pluginCookbookFilename = pluginInfo["cookbook_filename"]
        pluginCookbook = pluginInfo["cookbook"] ? pluginInfo["cookbook"] : new_resource.cookbook_name.to_s
        pluginTarName = ::File.basename(pluginCookbookFilename, ".tar.gz")
        pluginTarLocation = "#{Chef::Config[:file_cache_path]}/#{pluginTarName}.tar.gz"
        if !pluginTarName
          raise Exception.new("Unable to parse plugin TAR filename from plugin cookbook file #{pluginCookbookFilename} in cookbook #{pluginCookbook}")
        end
  
        # Copy the .tar.gz file into the cache
        cookbook_file pluginTarLocation do
          action :create
          source pluginCookbookFilename
          cookbook pluginCookbook
          owner attributes["userName"]
          group attributes["userGroup"]
          mode "0700"
          backup false
        end
      elsif pluginInfo["url"]
        pluginUrl = pluginInfo["url"]
        pluginTarName = ::File.basename(URI.parse(pluginUrl).path.split("/").last, ".tar.gz")
        pluginTarLocation = "#{Chef::Config[:file_cache_path]}/#{pluginTarName}.tar.gz"
        if !pluginTarName
          raise Exception.new("Unable to parse plugin TAR filename from URL #{pluginInfo["url"]}")
        end

        remote_file pluginTarLocation do
          action :create
          source pluginUrl
          group attributes["userGroup"]
          owner attributes["userName"]
          mode "0755"
          backup false
        end
      elsif pluginInfo["file"]
        pluginTarLocation = pluginInfo["file"]
        pluginTarName = ::File.basename(pluginTarLocation, ".tar.gz")
        if !pluginTarName
          raise Exception.new("Unable to parse plugin TAR filename from plugin file #{pluginInfo["file"]}")
        end
      else
        raise Exception.new("A URL, file, or cookbook filename must be provided for plugin #{pluginName}")
      end

      pluginDir = ::File.join(pluginsDir, pluginName)

      directory pluginDir do
        action :delete
        recursive true
        only_if do
          ::File.exists? pluginDir
        end
      end
      
      # Unpack the .tar.gz file into the plugins directory
      bash "Unpack Plugin #{pluginName} to #{pluginsDir}" do
        user "root"
        cwd pluginsDir
    
        # Untar the archive and then move it to the final location
        code <<-EOH
         tar zxf #{pluginTarLocation}
        EOH
        
        returns [0]
      end

      # The plugins will extract to, typically, something like "#{pluginName}-3.3-SNAPSHOT" or "#{pluginName}-3.3".
      # Find that directory and move it to the desired final destination
      ruby_block "Install Plugin #{pluginName} to #{pluginDir}" do
        block do
          tarRegex = Regexp.new "#{pluginName}-\\d+\\.\\d+(\\.\\d+)*(-SNAPSHOT)?$"
          foundPath = nil
          Dir["#{pluginDir}-*"].each do |dir|
            if tarRegex.match(dir)
              foundPath = dir
              break
            end
          end
          
          if !foundPath
            raise Exception.new("Unable to locate untarred plugin directory in #{pluginsDir}")
          end
          
          FileUtils.mv foundPath, pluginDir
        end
        not_if { ::File.exist?(pluginDir) }
      end
    end
  end

  # Configure the service
  service attributes["serviceName"] do
    supports :start => true, :stop => true, :restart => true, :status => true
    action [ :enable ]
  end
  
  # If the post-startup script has been specified, then copy it
  if attributes["postStartupScript"]
    template "Copying post-startup script (#{attributes["postStartupScript"]["cookbook_filename"]})" do
      source attributes["postStartupScript"]["cookbook_filename"]
      cookbook attributes["postStartupScript"]["cookbook"] ? attributes["postStartupScript"]["cookbook"] : new_resource.cookbook_name.to_s
      mode 0700
      owner attributes["userName"]
      group attributes["userGroup"]
      backup false
      path "#{attributes["installDir"]}/bin/#{attributes["instanceName"]}_startup_hook.sh"
      variables attributes["postStartupScript"]["variables"]
    end
  end

  # Persist Flume metadata
  ruby_block "Write Flume metadata" do
    block do
      writeFlumeMetadata attributes["installDir"], flumeMetadata
    end
  end
  
  # Chef seems to occasionally ignore the status and assume that a Flume agent is running - bypass the service resource and shell it out
  bash "Restart #{attributes["serviceName"]}" do
    user "root"
    code <<-EOH
      service #{attributes["serviceName"]} restart
    EOH
  end
end

# Extract the name (less the file extension) of the GZipped TAR file from the given URI
def getNameOfTarFileFromURI regex, uri
  regex.match(uri).to_a.first
end

def readFlumeMetadata installDir
  jsonFilepath = "#{installDir}/conf/agent_metadata.json"
  if !::File.exists?(jsonFilepath)
    return nil
  end
  
  JSON.parse(IO.read(jsonFilepath))
end

def writeFlumeMetadata installDir, flumeMetadata
  jsonFilepath = "#{installDir}/conf/agent_metadata.json"

  ::File.open(jsonFilepath,"w") do |file|
    file.write(flumeMetadata.to_json)
  end
end