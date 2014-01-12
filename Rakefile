require 'chef/cookbook/metadata'
require 'json'

task :package do
	# Read in the metadata
	metadata_file = 'metadata.rb'
	metadata_rb = Chef::Cookbook::Metadata.new
	metadata_rb.from_file(metadata_file)

	# Generate the metadata.json
	File.open('metadata.json', 'wb') { |f| f.write(metadata_rb.to_json) }

	# The PackageTask for Rake puts a version in the folder name, which doesn't suit our needs
	# The cookbook name should match the folder name
	version_dir = "pkg/#{metadata_rb.version}"
	FileUtils.remove_dir(version_dir, true)
	dest_dir = "#{version_dir}/#{metadata_rb.name}"
	FileUtils.remove_dir(dest_dir, true)
	FileUtils.mkdir_p(dest_dir)
	FileUtils.cp_r(%w(attributes/ LICENSE metadata.json metadata.rb providers/ README.md resources/ templates/), dest_dir, :verbose => true)

	# TAR the folder
	tar_name = "#{metadata_rb.name}-#{metadata_rb.version}.tar"
	gzip_name = "#{tar_name}.gz"
	exec("cd #{version_dir}; tar -zcvf #{gzip_name} #{metadata_rb.name}")
end