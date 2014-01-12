require 'rake/packagetask'
require 'chef/cookbook/metadata'

metadata_file = 'metadata.rb'
metadata = Chef::Cookbook::Metadata.new
metadata.from_file(metadata_file)

Rake::PackageTask.new(metadata.name, metadata.version) do |p|
    p.need_tar_gz = true
    p.package_files.include("./")
end