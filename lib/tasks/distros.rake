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
      # Extract distro details from SBOM data
      # First pass: collect all unique filenames with their images
      files_map = {}

      missing.each do |distro_name, count|
        # Find a version with SBOM data for this distro
        version = Version.joins(:sbom_record).where(distro_name: distro_name).first
        next unless version&.sbom_data

        distro_data = version.sbom_data['distro']
        next unless distro_data

        # Extract fields from distro data
        pretty_name = distro_data['prettyName']
        name = distro_data['name']
        id_field = distro_data['id']
        version_id = distro_data['versionID']
        variant_id = distro_data['variantID']

        # Skip if name contains escape sequences or looks malformed
        next if name&.include?('\n') || pretty_name&.include?('\n')
        next if name&.include?('"') || pretty_name&.include?('"')

        # Group by NAME (the base distro name, not PRETTY_NAME which includes version)
        base_name = name || pretty_name
        next unless base_name
        next if base_name.length > 100  # Skip suspiciously long names

        # Generate suggested filename with version
        # Replace non-alphabetic characters with underscore
        base_filename = (id_field || name || distro_name).downcase.gsub(/[^a-z]+/, '_').gsub(/^_|_$/, '')

        # Limit base_filename length
        base_filename = base_filename[0..50] if base_filename.length > 50

        version_part = (version_id || 'unknown').to_s.gsub(/[^a-z0-9.]+/, '_').gsub(/^_|_$/, '')
        version_part = version_part[0..30] if version_part.length > 30

        # Build filename: base/version or base/variant/version
        if variant_id.present?
          # Has variant: fedora/aurora/40
          variant_part = variant_id.to_s.downcase.gsub(/[^a-z]+/, '_').gsub(/^_|_$/, '')
          variant_part = variant_part[0..30] if variant_part.length > 30
          filename = "#{base_filename}/#{variant_part}/#{version_part}"
        else
          # No variant: alpine/3.19.0
          filename = "#{base_filename}/#{version_part}"
        end

        # Get the Docker image reference
        image_name = "#{version.package.name}:#{version.number}"

        # Use filename as the unique key - only store first occurrence
        if files_map[filename]
          files_map[filename][:count] += count
        else
          files_map[filename] = {
            base_name: base_name,
            version_id: version_id,
            variant_id: variant_id,
            count: count,
            image: image_name,
            filename: filename
          }
        end
      end

      # Second pass: organize by base_name and variant for display
      # Also separate into "existing distro, missing version" vs "completely new distro"
      existing_distros = {}
      new_distros = {}

      # Get list of existing distro base names from the database
      existing_distro_names = Distro.distinct.pluck(:name).compact.map(&:downcase)

      files_map.values.each do |entry|
        base_name = entry[:base_name]
        variant_id = entry[:variant_id]
        variant_key = variant_id || "(no variant)"

        # Check if we have this distro already (by name match)
        target = existing_distro_names.include?(base_name.downcase) ? existing_distros : new_distros

        target[base_name] ||= {}
        target[base_name][variant_key] ||= {}
        target[base_name][variant_key][entry[:filename]] = entry
      end

      if existing_distros.empty? && new_distros.empty?
        puts "No SBOM data available for missing distros"
      else
        if existing_distros.any?
          puts "="*80
          puts "MISSING VERSIONS FOR EXISTING DISTROS (#{existing_distros.size} distros)"
          puts "="*80
          puts ""

          existing_distros.sort.each do |base_name, variants|
            puts "#{base_name}:"

            # Check if we have actual variants or just the "(no variant)" group
            has_variants = variants.keys.any? { |k| k != "(no variant)" }

            if has_variants
              # Display with variant grouping
              variants.sort.each do |variant_id, entries_hash|
                if variant_id == "(no variant)"
                  puts "  (no variant):"
                else
                  puts "  variant: #{variant_id}"
                end

                entries_hash.values.sort_by { |e| e[:version_id].to_s }.each do |entry|
                  version_display = entry[:version_id] || "(no version)"
                  puts "    - version: #{version_display} (#{entry[:count]} images)"
                  puts "      docker run --rm #{entry[:image]} cat /etc/os-release > #{entry[:filename]}"
                end
              end
            else
              # No variants, just list versions directly
              entries = variants.values.flat_map(&:values)
              entries.sort_by { |e| e[:version_id].to_s }.each do |entry|
                version_display = entry[:version_id] || "(no version)"
                puts "  - version: #{version_display} (#{entry[:count]} images)"
                puts "    docker run --rm #{entry[:image]} cat /etc/os-release > #{entry[:filename]}"
              end
            end

            puts ""
          end
        end

        if new_distros.any?
          puts "="*80
          puts "COMPLETELY NEW DISTROS (#{new_distros.size} distros)"
          puts "="*80
          puts ""

          new_distros.sort.each do |base_name, variants|
            puts "#{base_name}:"

            # Check if we have actual variants or just the "(no variant)" group
            has_variants = variants.keys.any? { |k| k != "(no variant)" }

            if has_variants
              # Display with variant grouping
              variants.sort.each do |variant_id, entries_hash|
                if variant_id == "(no variant)"
                  puts "  (no variant):"
                else
                  puts "  variant: #{variant_id}"
                end

                entries_hash.values.sort_by { |e| e[:version_id].to_s }.each do |entry|
                  version_display = entry[:version_id] || "(no version)"
                  puts "    - version: #{version_display} (#{entry[:count]} images)"
                  puts "      docker run --rm #{entry[:image]} cat /etc/os-release > #{entry[:filename]}"
                end
              end
            else
              # No variants, just list versions directly
              entries = variants.values.flat_map(&:values)
              entries.sort_by { |e| e[:version_id].to_s }.each do |entry|
                version_display = entry[:version_id] || "(no version)"
                puts "  - version: #{version_display} (#{entry[:count]} images)"
                puts "    docker run --rm #{entry[:image]} cat /etc/os-release > #{entry[:filename]}"
              end
            end

            puts ""
          end
        end

        puts "Copy the docker commands above to extract os-release files locally."
        puts "Then contribute to: https://github.com/which-distro/os-release"
      end
    end
  end

  desc "Extract os-release files from missing distros using actual Docker images"
  task extract_missing: :environment do
    missing = Distro.missing_from_versions

    if missing.empty?
      puts "No missing distros found!"
      exit 0
    end

    extracted_count = 0

    missing.each do |distro_name, count|
      # Find a version with this distro_name that has SBOM data
      version = Version.joins(:sbom_record).where(distro_name: distro_name).first
      next unless version

      distro_data = version.sbom_data&.dig('distro')
      next unless distro_data

      image_name = "#{version.package.name}:#{version.number}"
      puts "\n" + "="*80
      puts "Processing: #{distro_name} (#{count} images)"
      puts "Using image: #{image_name}"
      puts "-"*80

      begin
        # Extract os-release using the version's method
        os_release_content = version.extract_os_release

        if os_release_content.present?
          # Parse to get fields for filename
          attributes = Distro.parse_os_release(os_release_content)

          # Create filename based on distro structure
          # Format: distro-name or distro-name-variant for variants
          base = (attributes[:id_field] || attributes[:name] || distro_name).downcase.gsub(/[^a-z0-9]+/, '-')

          filename = if attributes[:variant_id].present?
            # Has variant: e.g., fedora-coreos
            "#{base}-#{attributes[:variant_id].downcase.gsub(/[^a-z0-9]+/, '-')}"
          else
            # No variant: just use base name
            base
          end

          # Remove leading/trailing dashes
          filename = filename.gsub(/^-|-$/, '')

          extracted_count += 1

          puts "Suggested filename: #{filename}"
          puts ""
          puts "Content:"
          puts os_release_content
          puts ""
        else
          puts "Failed to extract os-release"
        end
      rescue => e
        puts "Error: #{e.message}"
      end
    end

    puts "\n" + "="*80
    if extracted_count > 0
      puts "Extracted #{extracted_count} os-release file(s)"
      puts ""
      puts "Next steps:"
      puts "1. Copy the content above for each file"
      puts "2. Fork https://github.com/which-distro/os-release"
      puts "3. Create files with the suggested filenames in your fork"
      puts "4. Submit a pull request"
    else
      puts "No os-release files were extracted successfully"
    end
  end
end
