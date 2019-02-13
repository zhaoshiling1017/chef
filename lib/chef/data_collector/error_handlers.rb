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

class Chef
  class DataCollector
    module ErrorHandlers
      attr_reader :node_name

      def error_description
        @error_description ||= {}
      end

      def resource_failed(new_resource, action, exception)
        description = Formatters::ErrorMapper.resource_failed(new_resource, action, exception)
        @error_description = description.for_json
      end

      def registration_failed(node_name, exception, config)
        description = Formatters::ErrorMapper.registration_failed(node_name, exception, config)
        @node_name = node_name
        @error_description = description.for_json
      end

      def node_load_failed(node_name, exception, config)
        description = Formatters::ErrorMapper.node_load_failed(node_name, exception, config)
        @node_name = node_name
        @error_description = description.for_json
      end

      def run_list_expand_failed(node, exception)
        description = Formatters::ErrorMapper.run_list_expand_failed(node, exception)
        @error_description = description.for_json
      end

      def cookbook_resolution_failed(expanded_run_list, exception)
        description = Formatters::ErrorMapper.cookbook_resolution_failed(expanded_run_list, exception)
        @error_description = description.for_json
      end

      def cookbook_sync_failed(cookbooks, exception)
        description = Formatters::ErrorMapper.cookbook_sync_failed(cookbooks, exception)
        @error_description = description.for_json
      end

      def file_load_failed(path, exception)
        description = Formatters::ErrorMapper.file_load_failed(path, exception)
        @error_description = description.for_json
      end

      def recipe_not_found(exception)
        description = Formatters::ErrorMapper.file_load_failed(nil, exception)
        @error_description = description.for_json
      end
    end
  end
end
