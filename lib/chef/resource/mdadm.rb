#
# Author:: Joe Williams (<joe@joetify.com>)
# Author:: Tyler Cloke (<tyler@chef.io>)
# Copyright:: Copyright 2009-2016, Joe Williams
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

require "chef/resource"

class Chef
  class Resource
    class Mdadm < Chef::Resource
      resource_name :mdadm
      provides :mdadm

      description "Use the mdadm resource to manage RAID devices in a Linux environment using the mdadm utility. The mdadm resource will create and assemble an array, but it will not create the config file that is used to persist the array upon reboot. If the config file is required, it must be done by specifying a template with the correct array layout, and then by using the mount provider to create a file systems table (fstab) entry."

      property :chunk, Integer, default: 16
      property :devices, Array, default: lazy { [] }
      property :level, Integer, default: 1
      property :metadata, String, default: "0.90"
      property :bitmap, String
      property :raid_device, String, identity: true, name_property: true
      property :layout, String

      load_current_value do |desired|
        logger.debug("#{desired} checking for software raid device #{desired.raid_device}")

        device_not_found = 4
        mdadm = shell_out!("mdadm --detail --test #{desired.raid_device}", :returns => [0, device_not_found])
        if mdadm.status == 0
          raid_device desired.raid_device
        else
          current_value_does_not_exist!
        end
      end

      action :create do
        unless current_resource
          converge_by("create RAID device #{new_resource.raid_device}") do
            command = "yes | mdadm --create #{new_resource.raid_device} --level #{new_resource.level}"
            command << " --chunk=#{new_resource.chunk}" unless new_resource.level == 1
            command << " --metadata=#{new_resource.metadata}"
            command << " --bitmap=#{new_resource.bitmap}" if new_resource.bitmap
            command << " --layout=#{new_resource.layout}" if new_resource.layout
            command << " --raid-devices #{new_resource.devices.length} #{new_resource.devices.join(" ")}"
            logger.trace("#{new_resource} mdadm command: #{command}")
            shell_out!(command)
            logger.info("#{new_resource} created raid device (#{new_resource.raid_device})")
          end
        else
          logger.debug("#{new_resource} raid device already exists, skipping create (#{new_resource.raid_device})")
        end
      end

      action :assemble do
        unless current_resource
          converge_by("assemble RAID device #{new_resource.raid_device}") do
            command = "yes | mdadm --assemble #{new_resource.raid_device} #{new_resource.devices.join(" ")}"
            logger.trace("#{new_resource} mdadm command: #{command}")
            shell_out!(command)
            logger.info("#{new_resource} assembled raid device (#{new_resource.raid_device})")
          end
        else
          logger.debug("#{new_resource} raid device already exists, skipping assemble (#{new_resource.raid_device})")
        end
      end

      action :stop do
        if current_resource
          converge_by("stop RAID device #{new_resource.raid_device}") do
            command = "yes | mdadm --stop #{new_resource.raid_device}"
            logger.trace("#{new_resource} mdadm command: #{command}")
            shell_out!(command)
            logger.info("#{new_resource} stopped raid device (#{new_resource.raid_device})")
          end
        else
          logger.debug("#{new_resource} raid device doesn't exist (#{new_resource.raid_device}) - not stopping")
        end
      end
    end
  end
end
