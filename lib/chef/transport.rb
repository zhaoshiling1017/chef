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

require "chef-config/mixin/credentials"
require "train"

class Chef
  class Transport
    #
    # Returns a RFC099 credentials profile as a hash
    #
    def self.load_credentials(profile)
      extend ChefConfig::Mixin::Credentials

      # ChefConfig::Mixin::Credentials.credentials_file_path is designed around knife
      #
      # Credentials file preference:
      #
      # 1) target_mode.credentials_file
      # 2) /etc/chef/TARGET_MODE_HOST/credentials
      # 3) #credentials_file_path from parent ($HOME/.chef/credentials)
      #
      def credentials_file_path
        tm_config = Chef::Config.target_mode

        credentials_file =
          if tm_config.credentials_file
            if File.exists?(tm_config.credentials_file)
              tm_config.credentials_file
            else
              raise ArgumentError, "Credentials file specified for target mode does not exist: '#{tm_config.credentials_file}'"
            end
          elsif File.exists?(Chef::Config.platform_specific_path("/etc/chef/#{profile}/credentials"))
            Chef::Config.platform_specific_path("/etc/chef/#{profile}/credentials")
          else
            super
          end
        if credentials_file
          Chef::Log.debug("Loading credentials file '#{credentials_file}' for target '#{profile}'")
        else
          Chef::Log.debug("No credentials file found for target '#{profile}'")
        end

        credentials_file
      end

      credentials = parse_credentials_file
      # todo raise warning if { "host" => { "domain" => { "org" => { "key" => "val"} } } } exists
      # host names must be specified in credentials file as ['foo.example.org'] with quotes
      if !credentials.nil? && !credentials[profile].nil?
        # Tomlrb.load_file returns a hash with keys as strings that don't match with #key?
        Mash.from_hash(credentials[profile]).symbolize_keys
      else
        nil
      end
    end

    def self.build_connection(logger = Chef::Log.with_child(subsystem: "transport"))
      # TODO: Consider supporting parsing the protocol from a URI passed to `--target`
      #
      train_config = Hash.new

      # Load the target_mode config context from Chef::Config, and place any valid settings into the train configuration
      tm_config = Chef::Config.target_mode
      protocol = tm_config.protocol
      train_config = tm_config.to_hash.select { |k| Train.options(protocol).key?(k) }
      Chef::Log.trace("Using target mode options from Chef config file: #{train_config.keys.join(', ')}") if train_config

      # Load the credentials file, and place any valid settings into the train configuration
      credentials = load_credentials(tm_config.host)
      if credentials
        valid_settings = credentials.select { |k| Train.options(protocol).key?(k.to_sym) }
        train_config.merge!(valid_settings)
        Chef::Log.trace("Using target mode options from credentials file: #{valid_settings.keys.join(', ')}") if valid_settings
      end

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
