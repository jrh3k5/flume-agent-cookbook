# coding: UTF-8
def initialize(*args)
  super
  @action = :create
  
  @flumePlugins = Hash.new

  @rmLibs = Array.new
end

actions :create

attribute :userName,            :kind_of => String
attribute :userGroup,           :kind_of => String
attribute :agentName,           :kind_of => String

attr_reader :agentConfigFile
attr_reader :flumePlugins
attr_reader :loggingProps
attr_reader :flumeEnvSh
attr_reader :jmxProps
attr_reader :agentPostStartupScript
attr_reader :rmLibs

@@POST_START_SCRIPT_ATTRIBUTES = ["cookbook_filename", "cookbook", "variables"]
def postStartupScript(&block)
  @agentPostStartupScript = BlockHash.new(@@POST_START_SCRIPT_ATTRIBUTES, &block)
end

@@AGENT_CONFIG_FILE_ATTRIBUTES = ["cookbook_filename", "cookbook", "variables"]
  
def configFile(&block)
  @agentConfigFile = BlockHash.new(@@AGENT_CONFIG_FILE_ATTRIBUTES, &block)
end

@@PLUGIN_ATTRIBUTES = ["cookbook_filename", "cookbook", "url", "file"]

def flumePlugin(pluginName, &block)
  if !pluginName or pluginName.empty?
    raise "You must provide a name for your Flume Plugin"
  end
  
  @flumePlugins[pluginName] = BlockHash.new(@@PLUGIN_ATTRIBUTES, &block)
end

@@LOGGING_ATTRIBUTES = ["cookbook_filename", "cookbook", "variables"]

def loggingProperties(&block)
  @loggingProps = BlockHash.new(@@LOGGING_ATTRIBUTES, &block)
end

@@FLUME_ENV_SH_ATTRIBUTES = ["cookbook_filename", "cookbook", "variables"]

def flumeEnv(&block)
  @flumeEnvSh = BlockHash.new(@@FLUME_ENV_SH_ATTRIBUTES, &block)
end

@@JMX_ATTRIBUTES = ["port"]

def jmx(&block)
  @jmxProps = BlockHash.new(@@JMX_ATTRIBUTES, &block)
end

def rmLib(filename, &block)
  if !filename or filename.empty?
    raise "You must provide the filename of the library to be removed"
  end
  @rmLibs.push(filename)
end

# A Hash that takes in a &block to populate itself. It also takes in a list of 'attributes' (you can think of this as a white list)
# such that if a method called by the &block is on the white list we store the method name (key) with its arguments (value). If
# the method is not on the white list then we throw the method call up a level and hope it works there
class BlockHash < Hash
  def initialize(attribute_list, &block)
    @self_before_instance_eval = eval "self", block.binding
    @attribute_list = attribute_list
    instance_eval(&block)
  end

  # Gives consumers the ability to reference to things outside the block
  def _previousSelf(method, *args, &block)
    Chef::Log.warn "This method is deprecated without replacement as it is no longer necessary"
    @self_before_instance_eval.send method, *args, &block
  end

  def method_missing(m, *args, &block)
    if block_given?
      raise "&block value is not supported"
    end

    if @attribute_list.include? m.to_s
      store m.to_s, (args.length == 1 ? args[0] : args)
    else
      # Not on the white list, try the level above us
      @self_before_instance_eval.send m, *args, &block
    end
  end

end