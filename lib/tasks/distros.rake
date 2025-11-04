namespace :distros do
  desc "Sync distros from which-distro/os-release repository"
  task sync_daily: :environment do
    Distro.sync_from_github
  end

  desc "Update versions_count for all distros"
  task update_counts: :environment do
    puts "Updating versions counts for all distros..."
    Distro.update_all_versions_counts
    puts "Done! Updated #{Distro.count} distros."
  end

  desc "Backfill distro_name from existing SBOM data for versions where it's nil"
  task backfill_names: :environment do
    puts "Finding versions needing distro_name backfill..."
    result = Version.backfill_all_distro_names
    puts "Backfill complete!"
    puts "Total versions needing backfill: #{result[:total]}"
    puts "Successfully backfilled: #{result[:backfilled]}"
    puts "Failed: #{result[:failed]}"
  end
end
