#
# Author:: Steven Danna (steve@chef.io)
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
require "chef/config"
require "chef/mixin/params_validate"
require "chef/mixin/from_file"
require "chef/mixin/versioned_api"
require "chef/mash"
require "chef/json_compat"
require "chef/search/query"
require "chef/mixin/api_version_request_handling"
require "chef/exceptions"
require "chef/server_api"
require "chef/user/user_base"

# OSC 11 BACKWARDS COMPATIBILITY NOTE (remove after OSC 11 support ends)
#
# In general, Chef::UserV1 is no longer expected to support Open Source Chef 11 Server requests.
# The object that handles those requests remain in the Chef::User namespace.
# This code will be moved to the Chef::User namespace as of Chef 13.
#
# Exception: self.list is backwards compatible with OSC 11
class Chef
  class User
    class V1 < Base

      include Chef::Mixin::FromFile
      include Chef::Mixin::ParamsValidate
      extend Chef::Mixin::VersionedAPI

      minimum_api_version 1

      def to_hash
        result = {
          "username" => @username,
        }
        result["display_name"] = @display_name unless @display_name.nil?
        result["first_name"] = @first_name unless @first_name.nil?
        result["middle_name"] = @middle_name unless @middle_name.nil?
        result["last_name"] = @last_name unless @last_name.nil?
        result["email"] = @email unless @email.nil?
        result["password"] = @password unless @password.nil?
        result["public_key"] = @public_key unless @public_key.nil?
        result["private_key"] = @private_key unless @private_key.nil?
        result["create_key"] = @create_key unless @create_key.nil?
        result
      end

      def create
        payload = {
          :username => @username,
          :display_name => @display_name,
          :first_name => @first_name,
          :last_name => @last_name,
          :email => @email,
          :password => @password,
        }
        payload[:public_key] = @public_key unless @public_key.nil?
        payload[:create_key] = @create_key unless @create_key.nil?
        payload[:middle_name] = @middle_name unless @middle_name.nil?
        raise Chef::Exceptions::InvalidUserAttribute, "You cannot set both public_key and create_key for create." if !@create_key.nil? && !@public_key.nil?
        new_user = chef_rest.post("users", payload)

        # get the private_key out of the chef_key hash if it exists
        if new_user["chef_key"]
          if new_user["chef_key"]["private_key"]
            new_user["private_key"] = new_user["chef_key"]["private_key"]
          end
          new_user["public_key"] = new_user["chef_key"]["public_key"]
          new_user.delete("chef_key")
        end

        Chef::User::V1.from_hash(self.to_hash.merge(new_user))
      end

      def update(new_key = false)
        payload = { :username => username }
        payload[:display_name] = display_name unless display_name.nil?
        payload[:first_name] = first_name unless first_name.nil?
        payload[:middle_name] = middle_name unless middle_name.nil?
        payload[:last_name] = last_name unless last_name.nil?
        payload[:email] = email unless email.nil?
        payload[:password] = password unless password.nil?

        # API V1 will fail if these key fields are defined, and try V0 below if relevant 400 is returned
        payload[:public_key] = public_key unless public_key.nil?
        payload[:private_key] = new_key if new_key

        updated_user = chef_rest.put("users/#{username}", payload)
        Chef::User::V1.from_hash(self.to_hash.merge(updated_user))
      end

      # Note: remove after API v0 no longer supported by client (and knife command).
      def reregister
        error_msg = reregister_only_v0_supported_error_msg(max_version, min_version)
        raise Chef::Exceptions::OnlyApiVersion0SupportedForAction.new(error_msg)
      end

      # Class Methods

      def self.from_hash(user_hash)
        user = Chef::User::V1.new
        user.username user_hash["username"]
        user.display_name user_hash["display_name"] if user_hash.key?("display_name")
        user.first_name user_hash["first_name"] if user_hash.key?("first_name")
        user.middle_name user_hash["middle_name"] if user_hash.key?("middle_name")
        user.last_name user_hash["last_name"] if user_hash.key?("last_name")
        user.email user_hash["email"] if user_hash.key?("email")
        user.password user_hash["password"] if user_hash.key?("password")
        user.public_key user_hash["public_key"] if user_hash.key?("public_key")
        user.private_key user_hash["private_key"] if user_hash.key?("private_key")
        user.create_key user_hash["create_key"] if user_hash.key?("create_key")
        user
      end

      def self.from_json(json)
        Chef::User::V1.from_hash(Chef::JSONCompat.from_json(json))
      end

      def self.json_create(json)
        Chef.deprecated(:json_auto_inflate, "Auto inflation of JSON data is deprecated. Please use Chef::User::V1#from_json or Chef::User::V1#load.")
        Chef::User::V1.from_json(json)
      end

      def self.list(inflate = false)
        response = Chef::ServerAPI.new(Chef::Config[:chef_server_url]).get("users")
        users = if response.is_a?(Array)
                  # EC 11 / CS 12 V0, V1
                  #   GET /organizations/<org>/users
                  transform_list_response(response)
                else
                  # OSC 11
                  #  GET /users
                  # EC 11 / CS 12 V0, V1
                  #  GET /users
                  response # OSC
                end

        if inflate
          users.inject({}) do |user_map, (name, _url)|
            user_map[name] = Chef::User::V1.load(name)
            user_map
          end
        else
          users
        end
      end

      def self.load(username)
        # will default to the current API version (Chef::Authenticator::DEFAULT_SERVER_API_VERSION)
        response = Chef::ServerAPI.new(Chef::Config[:chef_server_url]).get("users/#{username}")
        Chef::User::V1.from_hash(response)
      end

      # Gross.  Transforms an API response in the form of:
      # [ { "user" => { "username" => USERNAME }}, ...]
      # into the form
      # { "USERNAME" => "URI" }
      def self.transform_list_response(response)
        new_response = Hash.new
        response.each do |u|
          name = u["user"]["username"]
          new_response[name] = Chef::Config[:chef_server_url] + "/users/#{name}"
        end
        new_response
      end

      private_class_method :transform_list_response

    end
  end
end
