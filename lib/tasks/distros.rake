namespace :distros do
  desc "Sync distros from which-distro/os-release repository"
  task sync_daily: :environment do
    Distro.sync_from_github
  end

  desc "Update versions_count and total_downloads for all distros"
  task update_counts: :environment do
    puts "Updating versions counts for all distros..."
    Distro.update_all_versions_counts
    puts "Updating total downloads for all distros..."
    Distro.update_all_total_downloads
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

  desc "Show distro names from versions that are missing from distros table"
  task missing: :environment do
    puts "Finding distro names that appear in versions but not in distros table..."
    puts ""

    missing = Distro.missing_from_versions

    if missing.empty?
      puts "All distro names from versions are present in distros table!"
    else
      with_guess = missing.select { |name, _count| Distro.guess_docker_image_from_name(name).present? }
      without_guess = missing.select { |name, _count| Distro.guess_docker_image_from_name(name).nil? }

      if with_guess.any?
        puts "Found #{with_guess.count} missing distro(s) on Docker Hub:"
        puts ""
        puts "%-50s %-8s %s" % ["Distro Name", "Count", "Docker Hub Image"]
        puts "-" * 100

        with_guess.each do |name, count|
          guessed_image = Distro.guess_docker_image_from_name(name)
          puts "%-50s %-8s %s" % [name, count, guessed_image]
        end
        puts ""
        puts "Run 'rake distros:extract_missing' to extract os-release files from these images"
        puts ""
      end

      if without_guess.any?
        puts "Found #{without_guess.count} missing distro(s) not on Docker Hub:"
        puts ""
        without_guess.each do |name, count|
          puts "  #{name} (#{count} versions)"
        end
        puts ""
      end

      puts "These could be contributed to: https://github.com/which-distro/os-release"
    end
  end

  desc "Extract os-release files from missing distros using guessed Docker images"
  task extract_missing: :environment do
    missing = Distro.missing_from_versions

    if missing.empty?
      puts "No missing distros found!"
      exit 0
    end

    require 'tmpdir'

    Dir.mktmpdir do |tmp_dir|
      output_dir = File.join(tmp_dir, 'os-release-contributions')
      FileUtils.mkdir_p(output_dir)

      missing.each do |name, count|
        guessed_image = Distro.guess_docker_image_from_name(name)
        next unless guessed_image

        puts "Processing: #{name} (#{count} versions)"
        puts "  Guessed image: #{guessed_image}"

        begin
          # Pull the image
          puts "  Pulling image..."
          system('docker', 'pull', guessed_image, out: File::NULL, err: File::NULL)

          # Extract os-release
          puts "  Extracting /etc/os-release..."
          output, status = Open3.capture2('docker', 'run', '--rm', guessed_image, 'cat', '/etc/os-release')

          if status.success? && output.present?
            # Create filename from distro name
            filename = name.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')
            filepath = File.join(output_dir, filename)

            File.write(filepath, output)
            puts "  ✓ Saved to: #{filepath}"
            puts ""
          else
            puts "  ✗ Failed to extract os-release"
            puts ""
          end
        rescue => e
          puts "  ✗ Error: #{e.message}"
          puts ""
        end
      end

      if Dir.glob(File.join(output_dir, '*')).any?
        puts "Extracted os-release files saved to: #{output_dir}"
        puts "Review these files and consider contributing to https://github.com/which-distro/os-release"
      else
        puts "No os-release files were extracted successfully"
      end
    end
  end
end
