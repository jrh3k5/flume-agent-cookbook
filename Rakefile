require 'rake/packagetask'
require 'chef/cookbook/metadata'
require 'json'

# Read in the metadata
metadata_file = 'metadata.rb'
metadata_rb = Chef::Cookbook::Metadata.new
metadata_rb.from_file(metadata_file)

# Generate the metadata.json
File.open('metadata.json', 'wb') { |f| f.write(metadata_rb.to_json) }

Rake::PackageTask.new(metadata_rb.name, metadata_rb.version) do |p|
    p.need_tar_gz = true
    p.package_files.include("./**/*")
    p.package_files.exclude("./.*")
    p.package_files.exclude("./pkg/**/*")
    p.package_files.exclude("./pkg")
end