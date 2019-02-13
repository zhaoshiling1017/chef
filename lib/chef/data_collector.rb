#
# Author:: Adam Leff (<adamleff@chef.io>)
# Author:: Ryan Cragun (<ryan@chef.io>)
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

require "chef/server_api"
require "chef/http/simple_json"
require "chef/event_dispatch/base"
require "set"
require "chef/data_collector/node_uuid"
require "chef/data_collector/run_end_message"
require "chef/data_collector/run_start_message"
require "chef/data_collector/config_validation"
require "chef/data_collector/error_handlers"

class Chef
  class DataCollector

    # == Chef::DataCollector::Reporter
    # Provides an event handler that can be registered to report on Chef
    # run data. Unlike the existing Chef::ResourceReporter event handler,
    # the DataCollector handler is not tied to a Chef Server / Chef Reporting
    # and exports its data through a webhook-like mechanism to a configured
    # endpoint.
    #
    class Reporter < EventDispatch::Base
      include Chef::DataCollector::ErrorHandlers

      # handle to the expanded_run_list for messages
      attr_reader :expanded_run_list

      # handle to the run_status for messages
      attr_reader :run_status

      # handle to the node object
      attr_reader :node

      # accumulated list of deprecations
      attr_reader :deprecations

      # handle to the action_collection to gather resources from
      attr_reader :action_collection

      # handle to the events object so we can deregister
      attr_reader :events

      def initialize(events)
        @events = events
        @expanded_run_list       = {}
        @deprecations            = Set.new
      end

      def run_start(chef_version, run_status)
        events.unregister(self) unless should_be_enabled?
        @run_status = run_status
      end

      def node_load_success(node)
        @node = node
      end

      def action_collection_registration(action_collection)
        @action_collection = action_collection
        action_collection.register(self)
      end

      # Upon receipt, we will send our run start message to the
      # configured DataCollector endpoint. Depending on whether
      # the user has configured raise_on_failure, if we cannot
      # send the message, we will either disable the DataCollector
      # Reporter for the duration of this run, or we'll raise an
      # exception.
      #
      # see EventDispatch::Base#run_started
      #
      def run_started(run_status)
        # publish our node_uuid back to the node data object
        run_status.node.automatic[:chef_guid] = Chef::DataCollector::NodeUUID.node_uuid(run_status.node)

        # do sanity checks
        Chef::DataCollector::ConfigValidation.validate_server_url!
        Chef::DataCollector::ConfigValidation.validate_output_locations!

        send_run_start
      end

      # Append a received deprecation to the list of deprecations
      #
      # see EventDispatch::Base#deprecation
      #
      def deprecation(message, location = caller(2..2)[0])
        @deprecations << { message: message.message, url: message.url, location: message.location }
      end

      # Upon receipt, we will send our run completion message to the
      # configured DataCollector endpoint.
      #
      # see EventDispatch::Base#run_completed
      #
      def run_completed(node)
        send_run_completion("success")
      end

      # see EventDispatch::Base#run_failed
      #
      def run_failed(exception)
        send_run_completion("failure")
      end

      # The expanded run list is stored for later use by the run_completed
      # event and message.
      #
      # see EventDispatch::Base#run_list_expanded
      #
      def run_list_expanded(run_list_expansion)
        @expanded_run_list = run_list_expansion
      end

      private

      # Selects the type of HTTP client to use based on whether we are using
      # token-based or signed header authentication. Token authentication is
      # intended to be used primarily for Chef Solo in which case no signing
      # key will be available (in which case `Chef::ServerAPI.new()` would
      # raise an exception.
      # FIXME: rename to "http_client"
      def http
        @http ||= setup_http_client(Chef::Config[:data_collector][:server_url])
      end

      # FIXME: rename to "http_clients_for_output_locations" or something
      def http_output_locations
        @http_output_locations ||=
          begin
            Chef::Config[:data_collector][:output_locations][:urls].each_with_object({}) do |location_url, http_output_locations|
              http_output_locations[location_url] = setup_http_client(location_url)
            end
          end
      end

      def setup_http_client(url)
        if Chef::Config[:data_collector][:token].nil?
          Chef::ServerAPI.new(url, validate_utf8: false)
        else
          Chef::HTTP::SimpleJSON.new(url, validate_utf8: false)
        end
      end

      def send_to_data_collector(message)
        http.post(nil, message, headers) if Chef::Config[:data_collector][:server_url]
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET,
        Errno::ECONNREFUSED, EOFError, Net::HTTPBadResponse,
        Net::HTTPHeaderSyntaxError, Net::ProtocolError, OpenSSL::SSL::SSLError,
        Errno::EHOSTDOWN => e
        # Do not disable data collector reporter if additional output_locations have been specified
        events.unregister(self) unless Chef::Config[:data_collector][:output_locations]

        code = if e.respond_to?(:response) && e.response.code
                 e.response.code.to_s
               else
                 "Exception Code Empty"
               end

        msg = "Error while reporting run start to Data Collector. " \
          "URL: #{Chef::Config[:data_collector][:server_url]} " \
          "Exception: #{code} -- #{e.message} "

        if Chef::Config[:data_collector][:raise_on_failure]
          Chef::Log.error(msg)
          raise
        else
          # Make the message non-scary for folks who don't have automate:
          msg << " (This is normal if you do not have Chef Automate)"
          Chef::Log.info(msg)
        end
      end

      def send_to_output_locations(message)
        return unless Chef::Config[:data_collector][:output_locations]

        Chef::Config[:data_collector][:output_locations].each do |type, locations|
          locations.each do |location|
            send_to_file_location(location, message) if type == :files
            send_to_http_location(location, message) if type == :urls
          end
        end
      end

      def send_to_file_location(file_name, message)
        File.open(file_name, "a") do |fh|
          fh.puts Chef::JSONCompat.to_json(message)
        end
      end

      def send_to_http_location(http_url, message)
        @http_output_locations[http_url].post(nil, message, headers) if @http_output_locations[http_url]
      rescue
        # FIXME: this feels like poor behavior on several different levels, at least its a warn now...
        Chef::Log.warn("Data collector failed to send to URL location #{http_url}. Please check your configured data_collector.output_locations")
      end

      def sent_run_start?
        !!@sent_run_start
      end

      def send_run_start
        message = Chef::DataCollector::RunStartMessage.construct_message(self)
        send_to_data_collector(message)
        send_to_output_locations(message)
        @sent_run_start = true
      end

      #
      # Send any messages to the DataCollector endpoint that are necessary to
      # indicate the run has completed. Currently, two messages are sent:
      #
      # - An "action" message with the node object indicating it's been updated
      # - An "run_converge" (i.e. RunEnd) message with details about the run,
      #   what resources were modified/up-to-date/skipped, etc.
      #
      # @param opts [Hash] Additional details about the run, such as its success/failure.
      #
      def send_run_completion(status)
        # this is necessary to send a run_start message when we fail before the run_started chef event
        send_run_start unless sent_run_start?

        message = Chef::DataCollector::RunEndMessage.construct_message(self, status)
        send_to_data_collector(message)
        send_to_output_locations(message)
      end

      def headers
        headers = { "Content-Type" => "application/json" }

        unless Chef::Config[:data_collector][:token].nil?
          headers["x-data-collector-token"] = Chef::Config[:data_collector][:token]
          headers["x-data-collector-auth"]  = "version=1.0"
        end

        headers
      end

      # Whether or not to enable data collection:
      # * always disabled for why run mode
      # * disabled when the user sets `Chef::Config[:data_collector][:mode]` to a
      #   value that excludes the mode (client or solo) that we are running as
      # * disabled in solo mode if the user did not configure the auth token
      # * disabled if `Chef::Config[:data_collector][:server_url]` is set to a
      #   falsey value
      def should_be_enabled?
        running_mode = Chef::Config[:solo] || Chef::Config[:local_mode] ? :solo : :client
        want_mode = Chef::Config[:data_collector][:mode]

        case
        when Chef::Config[:why_run]
          Chef::Log.trace("data collector is disabled for why run mode")
          false
        when (want_mode != :both) && running_mode != want_mode
          Chef::Log.trace("data collector is configured to only run in #{Chef::Config[:data_collector][:mode]} modes, disabling it")
          false
        when !(Chef::Config[:data_collector][:server_url] || Chef::Config[:data_collector][:output_locations])
          Chef::Log.trace("Neither data collector URL or output locations have been configured, disabling data collector")
          false
        when running_mode == :solo && !Chef::Config[:data_collector][:token]
          Chef::Log.trace("Data collector token must be configured to use Chef Automate data collector with Chef Solo")
          false
        when running_mode == :client && Chef::Config[:data_collector][:token]
          Chef::Log.warn("Data collector token authentication is not recommended for client-server mode. " \
                         "Please upgrade Chef Server to 12.11.0 and remove the token from your config file " \
                         "to use key based authentication instead")
          true
        else
          true
        end
      end

    end
  end
end
