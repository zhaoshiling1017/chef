#
# Copyright 2014 Chef Software, Inc.
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

name "openssl-fips"
default_version "2.0.16"

license "OpenSSL"
license_file "https://www.openssl.org/source/license.html"
skip_transitive_dependency_licensing true

if windows?
  version("2.0.16") { source sha256: "42a660930d1e8b079b9618e5d44787b37e628742f9b7dbe53d986bffc84f8b5e", 
                             url: "http://shain-bucket.s3.amazonaws.com/fips-2.0-windows.zip" }
else
  version("2.0.16") { source sha256: "42a660930d1e8b079b9618e5d44787b37e628742f9b7dbe53d986bffc84f8b5e", 
                             url: "http://shain-bucket.s3.amazonaws.com/fips-2.0-linux.tar.gz" }
end

relative_path "fips-2.0"

build do
  copy "#{project_dir}", "#{install_dir}/embedded/fips"
end