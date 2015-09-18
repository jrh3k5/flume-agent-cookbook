name "flume_agent_test"

default_attributes "java" => {
  "install_flavor" => "oracle",
  "jdk_version" => "7",
  "oracle" => {
    "accept_oracle_download_terms" => true
  }
}