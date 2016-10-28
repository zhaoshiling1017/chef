name "chef-minibus"
default_version "local_source"

license :project_license

# For the specific super-special version "local_source", build the source from
# the local git checkout. This is what you'd want to occur by default if you
# just ran omnibus build locally.
version("local_source") do
  source path: File.expand_path("../..", project.files_path),
         # Since we are using the local repo, we try to not copy any files
         # that are generated in the process of bundle installing omnibus.
         # If the install steps are well-behaved, this should not matter
         # since we only perform bundle and gem installs from the
         # omnibus cache source directory, but we do this regardless
         # to maintain consistency between what a local build sees and
         # what a github based build will see.
         options: { exclude: [ "omnibus/vendor" ] }
end

# For any version other than "local_source", fetch from github.
if version != "local_source"
  source git: "git://github.com/chef/chef.git"
end

# For nokogiri
dependency "libxml2"
dependency "libxslt"
dependency "libiconv"
dependency "liblzma"
dependency "zlib"

# ruby and bundler and friends
dependency "ruby"
dependency "rubygems"
dependency "bundler"

build do
  # This is where we get the definitions below
  require_relative "../../files/chef/build-chef"
  extend BuildChef

  project_env = env.dup
  project_env["BUNDLE_GEMFILE"] = project_gemfile
end
