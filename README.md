# Description
Provides a mechanism for installing a Flume agent.

# Compatability

As of version 1.2, this has been validated to work on Chef 12.5.1.

# Providers

The following are a list of provided actions supplied by this cookbook.

## Create

This provider is enabled using the _:create_ action. It will install a Flume agent of your choosing. An example invocation might look like:

<pre>
# Install the Flume agent
flume_agent "my-agent" do
  action :create
  userName "flume"
  userGroup "flume"
  agentName "my-agent"

  postStartupScript do
    cookbook_filename "startup_hook_script.sh.erb"
  end

  loggingProperties do
    cookbook_filename "flume.log4j.properties.erb"
  end

  configFile do
    cookbook_filename "flume.properties.erb"
    variables(:my-arg => "a", :my-arg2 => "b")
  end

  flumePlugin "my-flume-plugin" do
    file "/usr/share/flume/my-flume-plugin.tar.gz"
  end

  flumeEnv do
    cookbook_filename "my-flume-env.sh.erb"
  end

  jmx do
    port 1234
  end

  rmLib "guava-10.0.1.jar"
end
</pre>

This takes, at a minimum, four parameters:

* **userName**: The name of the user under which this installation is to occur
* **userGroup**: The group to which the installation is to be long
* **agentName**: The name of the agent to be installed
* **configFile**: The configuration file to be used to direct the behavior of the Flume agent. This is described in further detail below.

### Configuration Providers

Nested within the provider are configuration elements that contain their own parameters.

#### configFile

This is a required element of your provider configuration. It tells Flume how to configure the agent it is going to install and start. It accepts the following parameters:

* **cookbook_filename**:  The name of the file stored in the cookbook to be copied (as a template)
* **cookbook**: _(optional)_ The name of the cookbook from which the file is to be copied; defaults to the cookbook calling the provider
* **variables**: _(optional)_ A hash of variables to be provided to the copied agent configuration file.

#### loggingProperties

Flume provides its own default logging configuration, but, if you so choose, you can provide your own log configuration. This should be a log4j configuration file. It accepts the following parameters:

* **cookbook_filename**: The name of the file stored in the cookbook to be copied (as a template)
* **cookbook**: _(optional)_ The name of the cookbook from which the file is to be copied; defaults to the cookbook calling the provider
* **variables**: _(optional)_ A hash of variables to be provided to the copied logging properties file.

#### flumePlugin

Flume supports a style of packaging up libraries to be provided as "plugins" to the Flume installation. Refer to the [Flume documentation](http://flume.apache.org/FlumeUserGuide.html#installing-third-party-plugins) for more details on the exact packaging contents. This cookbook expects all plugins to be packaged as a .tar.gz file.

At minimum, one of the following sources must be provided:

* **url**: A URL from which the .tar.gz file will be downloaded.
* **file**: A location on the local disk from which the .tar.gz file will be copied
* **cookbook_filename**: The name of a cookbook file that will be copied as the .tar.gz file.
    * Optionally, the **cookbook** parameter can be specified here to identify which cookbook the file should be copied. If not specified, it will be the name of the cookbook calling the provider.

The expected format of the provided Flume plugin bundle follows:

    my-project-1.0-my-plugin-flume-plugin.tar.gz
      |
      +- name-of-my-plugin
          |
          +- lib/
          |   |
          |   +- my-lib.jar
          +- libext/
              |
              +- a.jar
              +- b.jar

#### flumeEnv

Use this element to provide a <tt>flume-env.sh</tt> file template to be copied into the Flume installation. It takes the following parameters:

* **cookbook_filename**: The name of the file stored in the cookbook to be copied (as a template)
* **cookbook**: _(optional)_ The name of the cookbook from which the file is to be copied; defaults to the cookbook calling the provider
* **variables**: _(optional)_ A hash of variables to be provided to the copied logging properties file.

#### postStartupScript

Starting with version 1.0.7 of this cookbook, the provider now provides a hook allowing consumers to specify a shell script to be executed following the startup of the agent. This allows the injection of, for example, the execution of a health check to ensure that the agent is available. It takes the following parameters:

* **cookbook_filename**: The name of the file stored in the cookbook to be copied (as a template)
* **cookbook**: _(optional)_ The name of the cookbook from which the file is to be copied; defaults to the cookbook calling the provider
* **variables**: _(optional)_ A hash of variables to be provided to the copied script

#### jmx

This block enables JMX reporting of the behavior of the agent. It takes the following parameter:

* **port**: The port on which the agent will publish its JMX statistics.

#### rmLib

(since 1.1) Flume plugins do not get loaded in classloaders isolated from the main classpath of the Flume agent; as a result, dependency convergence issues can arise (such as Guava incompatibilities). To help with this, the option is given as part of this cookbook to have it remove libraries from `lib/` directory beneath the Flume installation directory.

### Registered service

With this command, the agent will also install an _/etc/init.d/_ script following the pattern of "/etc/init.d/flume\_&lt;agentName&gt;". It supports the following commands:

* start
* stop
* restart
* status