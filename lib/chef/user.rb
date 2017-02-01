#
# Copyright:: Copyright 2012-2016, Chef Software, Inc.
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
require "chef/mixin/versioned_api"
require "chef/user/user_v0"
require "chef/user/user_v1"

class Chef
  class User
    extend Chef::Mixin::VersionedAPIFactory

    add_versioned_api_class Chef::User::V0
    add_versioned_api_class Chef::User::V1

    def_versioned_delegator :from_json
    def_versioned_delegator :from_hash
    def_versioned_delegator :list
    def_versioned_delegator :load
    def_versioned_delegator :transform_ohc_list_response
  end
end
