# Author:: Bryan McLellan <btm@loftninjas.org>
# Copyright:: Copyright 2018, Chef Software, Inc.
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

require "train"

class Chef
  class Transport
    def self.build_connection(logger = Chef::Log.with_child(subsystem: "transport"))

      protocol = Chef::Config.target_mode.protocol
      train_config = Chef::Config.target_mode.to_hash.select { |k| Train.options(protocol).key?(k) }
      train_config[:logger] = logger

      # Train handles connection retries for us
      train_connection = Train.create(protocol, train_config).connection
      train_connection.wait_until_ready
      train_connection
    rescue SocketError => e # likely a dns failure, not caught by train
      e.message.replace "Error connecting to #{train_connection.uri} - #{e.message}"
      raise e
    rescue Train::PluginLoadError
      logger.error("Invalid target mode protocol: #{protocol}")
      exit(false)
    end
  end
end
