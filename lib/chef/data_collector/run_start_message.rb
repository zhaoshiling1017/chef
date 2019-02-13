#
# Copyright:: Copyright 2012-2019, Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "chef/data_collector/message_helpers"
require "chef/data_collector/node_uuid"

class Chef
  class DataCollector
    module RunStartMessage
      extend Chef::DataCollector::MessageHelpers

      class << self
        #
        # Message payload that is sent to the DataCollector server at the
        # start of a Chef run.
        #
        # @param run_status [Chef::RunStatus] The RunStatus instance for this node/run.
        #
        # @return [Hash] A hash containing the run start message data.
        #
        def construct_message(data_collector)
          run_status = data_collector.run_status
          node = data_collector.node
          {
            "chef_server_fqdn" => chef_server_fqdn,
            "entity_uuid" => Chef::DataCollector::NodeUUID.node_uuid(node),
            "id" => run_status&.run_id,
            "message_version" => "1.0.0",
            "message_type" => "run_start",
            "node_name" => node&.name || data_collector.node_name,
            "organization_name" => organization,
            "run_id" => run_status&.run_id,
            "source" => collector_source,
            "start_time" => start_time(run_status),
          }
        end
      end
    end
  end
end
