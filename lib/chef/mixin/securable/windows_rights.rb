#
# Author:: John Keiser (jkeiser@chef.io)
# Copyright:: Copyright 2016, Chef Software, Inc.
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

require "chef/property/array_property"

class Chef
  module Mixin
    module Securable
      #
      # Property type for a "windows rights" value. Lets you write things like
      # this:
      #
      #     file "C:\\x.txt" do
      #       rights :read, ["Administrators","Everyone"]
      #       rights :deny, "Pinky"
      #       rights :full_control, "Users", applies_to_children: true
      #       rights :write, "John Keiser", applies_to_children: :containers_only, applies_to_self: false, one_level_deep: true
      #     end
      #
      # === rights_attribute
      # "meta-method" for dynamically creating rights attributes on resources.
      #
      # Multiple rights attributes can be declared. This enables resources to
      # have multiple rights attributes with separate runtime states.
      #
      # For example, +Chef::Resource::RemoteDirectory+ supports different
      # rights on the directories and files by declaring separate rights
      # attributes for each (rights and files_rights).
      #
      # ==== User Level API
      # Given a resource that calls
      #
      #   property :rights, WindowsRights
      #
      # Then the resource DSL could be used like this:
      #
      #   rights :read, ["Administrators","Everyone"]
      #   rights :deny, "Pinky"
      #   rights :full_control, "Users", :applies_to_children => true
      #   rights :write, "John Keiser", :applies_to_children => :containers_only, :applies_to_self => false, :one_level_deep => true
      #
      # ==== Internal Data Structure
      # rights attributes support multiple right declarations
      # in a single resource block--the data will be merged
      # into a single internal hash.
      #
      # The internal representation is a hash with the following keys:
      #
      # * `:permissions`: Integer of Windows permissions flags, 1..2^32
      # or one of `[:full_control, :modify, :read_execute, :read, :write]`
      # * `:principals`:  String or Array of Strings represnting usernames on
      # the system.
      # * `:applies_to_children` (optional): Boolean
      # * `:applies_to_self` (optional): Boolean
      # * `:one_level_deep` (optional): Boolean
      #
      class WindowsRights < Chef::Property::ArrayProperty
        def initialize(**options)
          # WindowsRightsValue declared below
          super(element_type: WindowsRightsValue, append: true, **options)
        end

        #
        # Called with arguments when `rights :full_control, "Users"` property is called.
        #
        # Takes the multiple arguments and stuffs them in a single hash to be coerced
        # into the final value in `coerce`.
        #
        def call(resource, *args)
          if args.size >= 2
            permissions, principals, args_hash = *args
            args_hash ||= {}
            args_hash[:permissions] = permissions
            args_hash[:principals] = principals
            super(resource, args_hash)
          else
            super
          end
        end

        # Validation for a single rights value
        WindowsRightsValue = Property.derive is: Hash,
          coerce: proc { |value|
            value[:permissions] = Array(value[:permissions])
            value[:principals] = Array(value[:principals])
            value[:applies_to_children] = v.to_sym if values[:applies_to_children] && value[:applies_to_children].is_a?(Integer)
            value
          },
          callbacks: {
            "permissions is required" => proc { |value| value.has_key?(:permissions) },
            "permissions must be an Array" => proc { |value| value[:permissions].is_a?(Enumerable) },
            "permissions values must be integers or :full_control, :modify, :read_execute, :read or :write" => proc do |value|
              value[:permissions].all? do |permission|
                case permission
                when Integer, :full_control, :modify, :read_execute, :read, :write
                  true
                else
                  false
                end
              end
            end,
            "permissions integer values must be positive and <= 32 bits" => proc do |value|
              value[:permissions].all? do |permission|
                !permission.is_a?(Integer) || permission >= 0 && permission < (1 << 32)
              end
            end,

            "principals is required" => proc { |value| value.has_key?(:principals) },
            "principals must be an Array" => proc { |value| value[:principals].is_a?(Enumerable) },
            "principals must be a String or a list of Strings" => proc do |value|
              value[:principals].all? { |principal| principal.is_a?(String) }
            end,

            ":applies_to_children must be true, false, :containers_only or :objects_only" => proc do |value|
              !value.has_key?(:applies_to_children) || [ true, false, :containers_only, :objects_only ].include?(value[:applies_to_children])
            end,
            ":applies_to_self must be true or false" => proc do |value|
              !value.has_key?(:applies_to_self) || [ true, false ].include?(value[:applies_to_self])
            end,
            ":applies_to_children must be true or false" => proc do |value|
              !value.has_key?(:applies_to_children) || [ true, false ].include?(value[:applies_to_children])
            end,
          }
      end
    end
  end
end
