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

require "spec_helper"
require "ostruct"

describe Chef::Resource::Mdadm do

  let(:node) { Chef::Node.new }
  let(:events) { Chef::EventDispatch::Dispatcher.new }
  let(:run_context) { Chef::RunContext.new(node, {}, events) }
  let(:collection) { double("resource collection") }
  let(:resource) { Chef::Resource::Mdadm.new("/dev/md1", run_context) }
  let(:provider) { resource.provider_for_action(:create) }
  let(:new_resource) { Chef::Resource::Mdadm.new("/dev/md1") }

  it "has a resource name of :mdadm" do
    expect(resource.resource_name).to eql(:mdadm)
  end

  it "has a default action of create" do
    expect(resource.action).to eql([:create])
  end

  it "accepts create, assemble, stop as actions" do
    expect { resource.action :create }.not_to raise_error
    expect { resource.action :assemble }.not_to raise_error
    expect { resource.action :stop }.not_to raise_error
  end

  it "allows you to set the raid_device property" do
    resource.raid_device "/dev/md3"
    expect(resource.raid_device).to eql("/dev/md3")
  end

  it "allows you to set the chunk property" do
    resource.chunk 256
    expect(resource.chunk).to eql(256)
  end

  it "allows you to set the level property" do
    resource.level 1
    expect(resource.level).to eql(1)
  end

  it "allows you to set the metadata property" do
    resource.metadata "1.2"
    expect(resource.metadata).to eql("1.2")
  end

  it "allows you to set the bitmap property" do
    resource.bitmap "internal"
    expect(resource.bitmap).to eql("internal")
  end

  it "allows you to set the layout property" do
    resource.layout "f2"
    expect(resource.layout).to eql("f2")
  end

  it "allows you to set the devices property" do
    resource.devices ["/dev/sda", "/dev/sdb"]
    expect(resource.devices).to eql(["/dev/sda", "/dev/sdb"])
  end

  describe "when it has devices, level, and chunk" do
    before do
      resource.raid_device("raider")
      resource.devices(%w{device1 device2})
      resource.level(1)
      resource.chunk(42)
    end

    it "describes its state" do
      state = resource.state_for_resource_reporter
      expect(state[:devices]).to eql(%w{device1 device2})
      expect(state[:level]).to eq(1)
      expect(state[:chunk]).to eq(42)
    end

    it "returns the raid device as its identity" do
      expect(resource.identity).to eq("raider")
    end
  end

  describe "when determining the current metadevice status" do
    it "determines that the metadevice exists when mdadm exit code is zero" do
      allow(resource).to receive(:shell_out!).with("mdadm --detail --test /dev/md1", :returns => [0, 4]).and_return(OpenStruct.new(:status => 0))
      provider.load_current_resource
      expect(provider.current_resource).not_to be_nil
    end

    it "determines that the metadevice does not exist when mdadm exit code is 4" do
      allow(resource).to receive(:shell_out!).with("mdadm --detail --test /dev/md1", :returns => [0, 4]).and_return(OpenStruct.new(:status => 4))
      provider.load_current_resource
      expect(provider.current_resource).to be_nil
    end
  end

  describe "after the metadevice status is known" do
    before(:each) do
      current_resource = Chef::Resource::Mdadm.new("/dev/md1")
      new_resource.level 5
      allow(provider).to receive(:load_current_resource).and_return(true)
      provider.current_resource = current_resource
    end

    describe "when creating the metadevice" do
      it "should create the raid device if it doesnt exist" do
        @current_resource.exists(false)
        expected_command = "yes | mdadm --create /dev/md1 --level 5 --chunk=16 --metadata=0.90 --raid-devices 3 /dev/sdz1 /dev/sdz2 /dev/sdz3"
        expect(provider).to receive(:shell_out!).with(expected_command)
        provider.run_action(:create)
      end

      it "should specify a bitmap only if set" do
        @current_resource.exists(false)
        new_resource.bitmap("grow")
        expected_command = "yes | mdadm --create /dev/md1 --level 5 --chunk=16 --metadata=0.90 --bitmap=grow --raid-devices 3 /dev/sdz1 /dev/sdz2 /dev/sdz3"
        expect(provider).to receive(:shell_out!).with(expected_command)
        provider.run_action(:create)
        expect(new_resource).to be_updated_by_last_action
      end

      it "should specify a layout only if set" do
        @current_resource.exists(false)
        new_resource.layout("rs")
        expected_command = "yes | mdadm --create /dev/md1 --level 5 --chunk=16 --metadata=0.90 --layout=rs --raid-devices 3 /dev/sdz1 /dev/sdz2 /dev/sdz3"
        expect(provider).to receive(:shell_out!).with(expected_command)
        provider.run_action(:create)
        expect(new_resource).to be_updated_by_last_action
      end

      it "should not specify a chunksize if raid level 1" do
        @current_resource.exists(false)
        @new_resource.level 1
        expected_command = "yes | mdadm --create /dev/md1 --level 1 --metadata=0.90 --raid-devices 3 /dev/sdz1 /dev/sdz2 /dev/sdz3"
        expect(@provider).to receive(:shell_out!).with(expected_command)
        @provider.run_action(:create)
        expect(@new_resource).to be_updated_by_last_action
      end

      it "should not create the raid device if it does exist" do
        @current_resource.exists(true)
        expect(@provider).not_to receive(:shell_out!)
        @provider.run_action(:create)
        expect(@new_resource).not_to be_updated_by_last_action
      end
    end

    describe "when asembling the metadevice" do
      it "should assemble the raid device if it doesnt exist" do
        @current_resource.exists(false)
        expected_mdadm_cmd = "yes | mdadm --assemble /dev/md1 /dev/sdz1 /dev/sdz2 /dev/sdz3"
        expect(@provider).to receive(:shell_out!).with(expected_mdadm_cmd)
        @provider.run_action(:assemble)
        expect(@new_resource).to be_updated_by_last_action
      end

      it "should not assemble the raid device if it doesnt exist" do
        @current_resource.exists(true)
        expect(@provider).not_to receive(:shell_out!)
        @provider.run_action(:assemble)
        expect(@new_resource).not_to be_updated_by_last_action
      end
    end

    describe "when stopping the metadevice" do

      it "should stop the raid device if it exists" do
        @current_resource.exists(true)
        expected_mdadm_cmd = "yes | mdadm --stop /dev/md1"
        expect(@provider).to receive(:shell_out!).with(expected_mdadm_cmd)
        @provider.run_action(:stop)
        expect(@new_resource).to be_updated_by_last_action
      end

      it "should not attempt to stop the raid device if it does not exist" do
        @current_resource.exists(false)
        expect(@provider).not_to receive(:shell_out!)
        @provider.run_action(:stop)
        expect(@new_resource).not_to be_updated_by_last_action
      end
    end
  end

end
