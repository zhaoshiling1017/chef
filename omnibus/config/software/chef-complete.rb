name "chef-complete"

license :project_license
skip_transitive_dependency_licensing true
fips_enabled = (project.overrides[:fips] && project.overrides[:fips][:enabled]) || true

dependency "chef"
dependency "chef-appbundle"
dependency "chef-cleanup"

dependency "gem-permissions"
dependency "shebang-cleanup"
dependency "version-manifest"
dependency "openssl-customization"

if fips_enabled
   dependency "stunnel"
end

if windows?
  # TODO can this be safely moved to before the chef?
  # It would make caching better ...
  dependency "ruby-windows-devkit"
  dependency "ruby-windows-devkit-bash"
end
