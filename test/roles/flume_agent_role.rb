name "flume_agent_role"
description "A role used to test the Flume agent cookbook"
run_list ["java::default", "test_flume_consumer::default"]

default_attributes "sentinel" => {
    "service" => {
      "processing_agent" => {
        "instance" => {
          "count" => 2
        }
      },
      "storage_agent" => {
        "instance" => {
          "count" => 1
        }
      }
    }
  }