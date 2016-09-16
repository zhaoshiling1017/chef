#
# Author:: Seth Chisamore (<schisamo@chef.io>)
# Copyright:: Copyright 2011-2016, Chef Software Inc.
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

require "chef/mixin/properties"
require "chef/platform/query_helpers"
require "chef/mixin/securable/windows_rights"

class Chef
  module Mixin
    module Securable

      include Chef::Mixin::Properties

      #
      # The owner of this file/directory.
      #
      property :owner, Chef::Config[:user_valid_regex]
      alias :user :owner
      alias :user= :owner=

      #
      # The group this file/directory belongs to.
      #
      property :group, Chef::Config[:group_valid_regex]

      #
      # The mode of this file/directory, e.g. 0777 or "777".
      #
      property :mode, [ String, Integer ], callbacks: {
        "not in valid numeric range" => lambda do |m|
          if m.kind_of?(String)
            m =~ /^0/ || m = "0#{m}"
          end

          # Windows does not support the sticky or setuid bits
          if Chef::Platform.windows?
            Integer(m) <= 0777 && Integer(m) >= 0
          else
            Integer(m) <= 07777 && Integer(m) >= 0
          end
        end,
      }

      if Chef::Platform.windows?
        #
        # Whether this file/directory inherits rights from its parent.
        #
        property :inherits, Boolean

        #
        # Rights for this Windows file or directory in the form of an ACL.
        #
        property :rights, WindowsRightsProperty

        #
        # Rights to deny (blacklist) to this Windows file or directory in the form of an ACL.
        #
        property :deny_rights, WindowsRightsProperty
      end

    end
  end
end
