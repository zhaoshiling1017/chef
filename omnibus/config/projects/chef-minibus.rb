#
# Copyright 2012-2016, Chef Software, Inc.
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

name "chef-minibus"
friendly_name "Chef Client Omnibus Tree"
maintainer "Chef Software, Inc. <maintainers@chef.io>"
homepage "https://www.chef.io"
license "Apache-2.0"
license_file "../LICENSE"

build_iteration 1
# Do not use __FILE__ after this point, use current_file. If you use __FILE__
# after this point, any dependent defs (ex: angrychef) that use instance_eval
# will fail to work correctly.
current_file ||= __FILE__
version_file = File.expand_path("../../../../VERSION", current_file)
build_version IO.read(version_file).strip

if windows?
  # NOTE: Ruby DevKit fundamentally CANNOT be installed into "Program Files"
  #       Native gems will use gcc which will barf on files with spaces,
  #       which is only fixable if everyone in the world fixes their Makefiles
  install_dir  "#{default_root}/opscode/chef"
else
  install_dir "#{default_root}/chef"
end

# Global FIPS override flag.
if windows? || rhel?
  override :fips, enabled: true
end

# Load dynamically updated overrides
overrides_path = File.expand_path("../../../../omnibus_overrides.rb", current_file)
instance_eval(IO.read(overrides_path), overrides_path)

override :"ruby-windows-devkit", version: "4.5.2-20111229-1559" if windows? && windows_arch_i386?

dependency "preparation"
#dependency "chef-minibus"
proj_to_work_around_cleanroom = self

package :tarball
