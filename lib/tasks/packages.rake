namespace :packages do
  desc "Sync popular packages"
  task sync_popular: :environment do
    Package.sync_popular
  end

  desc "update usage counts"
  task update_counts: :environment do
    # PackageUsage.update_all_counts
  end

  desc 'resync outdated packages'
  task resync_outdated: :environment do
    Package.resync_outdated
  end

  desc 'sync all versions for a specific package'
  task :sync_all_versions, [:package_name] => :environment do |t, args|
    if args[:package_name].blank?
      puts "Usage: rake packages:sync_all_versions[package_name]"
      puts "Example: rake packages:sync_all_versions[library/debian]"
      exit 1
    end

    package = Package.find_by_name(args[:package_name])
    unless package
      puts "Package '#{args[:package_name]}' not found"
      exit 1
    end

    puts "Syncing all versions for #{package.name}..."
    package.sync_all_versions
    puts "Done! Synced #{package.versions.count} versions."
  end
end