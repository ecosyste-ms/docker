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
end