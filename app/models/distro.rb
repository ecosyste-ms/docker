class Distro < ApplicationRecord
  has_many :versions, primary_key: :pretty_name, foreign_key: :distro_name

  validates :pretty_name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, if: -> { pretty_name.present? && slug.blank? }

  def generate_slug
    self.slug = pretty_name.to_s.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')
  end

  def grouping_key
    # Use id_field if present and the name matches it reasonably well
    # Otherwise use the name to avoid grouping derivative distros with their base
    return nil if id_field.blank? && name.blank?

    if id_field.present? && name.present?
      # Check if name contains or closely matches the id_field
      normalized_name = name.downcase.gsub(/[^a-z0-9]/, '')
      normalized_id = id_field.downcase.gsub(/[^a-z0-9]/, '')

      # If the name contains the id or they're very similar, group by id_field
      if normalized_name.include?(normalized_id) || normalized_id.include?(normalized_name)
        id_field.downcase
      else
        # Name is different - this is likely a derivative distro
        # Group by the normalized name instead
        name.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')
      end
    elsif id_field.present?
      id_field.downcase
    else
      name.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')
    end
  end

  def display_name
    # For Puppy variants, extract the variant name from pretty_name
    if name == "Puppy" && pretty_name.present? && pretty_name != name
      # Extract variant from pretty_name (e.g., "S15Pup64 22.12" -> "S15Pup64")
      variant_name = pretty_name.split(' ').first
      "#{name} #{variant_name}"
    else
      name || id_field&.titleize
    end
  end

  def rolling_release?
    version_id.to_s.downcase == 'rolling' ||
      build_id.to_s.downcase == 'rolling' ||
      version_codename.to_s.downcase == 'rolling'
  end

  def version_display_text
    return "rolling" if rolling_release? || version_id.to_s.include?('TEMPLATE')

    display_text = version_id.presence || pretty_name

    if variant.present?
      "#{display_text} (#{variant})"
    elsif version_codename.present?
      "#{display_text} (#{version_codename})"
    elsif build_id.present? && build_id != version_id
      "#{display_text} - #{build_id}"
    elsif pretty_name.to_s.downcase.include?('stream')
      "#{display_text} Stream"
    else
      display_text
    end
  end

  def self.group_stats(distros)
    total_images = distros.sum(&:versions_count)
    total_downloads = distros.sum { |d| d.total_downloads || 0 }
    is_single_rolling = distros.count == 1 && distros.first.rolling_release?

    {
      total_images: total_images,
      total_downloads: total_downloads,
      is_single_rolling: is_single_rolling
    }
  end

  def update_versions_count
    count = versions.count
    update_column(:versions_count, count) if versions_count != count
  end

  def update_total_downloads
    downloads = Package.joins(:versions)
                      .where(versions: { distro_name: pretty_name })
                      .distinct
                      .sum(:downloads)
    update_column(:total_downloads, downloads) if total_downloads != downloads
  end

  def related_distros
    return Distro.none if id_like.blank?

    # ID_LIKE can contain multiple space-separated values
    like_ids = id_like.split(/\s+/)

    # Find distros where id_field matches any of the ID_LIKE values
    Distro.where(id_field: like_ids).where.not(id: id)
  end

  def likely_docker_image
    return nil unless id_field.present?

    # Map of known official images
    official_images = {
      'debian' => true,
      'ubuntu' => true,
      'alpine' => true,
      'fedora' => true,
      'centos' => true,
      'rocky' => true,
      'almalinux' => true,
      'amazonlinux' => 'amazonlinux',
      'arch' => 'archlinux',
      'opensuse' => 'opensuse/leap',
      'ol' => 'oraclelinux'
    }

    image_name = official_images[id_field.downcase]
    return nil if image_name == false || image_name.nil?

    # Use mapped name or fall back to id_field
    image_name = id_field.downcase if image_name == true

    # Determine tag based on version info
    tag = if version_codename.present? && ['debian', 'ubuntu'].include?(id_field.downcase)
            # Debian and Ubuntu use codenames
            version_codename
          elsif version_id.present?
            # Most use version_id
            version_id.to_s.gsub(/^v/, '') # Remove leading 'v' if present
          elsif variant.present?
            # Fedora variants might use this
            nil
          else
            nil
          end

    image_string = tag.present? ? "#{image_name}:#{tag}" : image_name

    {
      image: image_string,
      url: "https://hub.docker.com/_/#{image_name.split('/').last}",
      package_name: image_name
    }
  end

  def likely_package
    docker_info = likely_docker_image
    return nil unless docker_info.present?

    # Try to find package by name (official images are often "library/{name}" or just "{name}")
    package_name = docker_info[:package_name]

    Package.find_by_name("library/#{package_name}") || Package.find_by_name(package_name)
  end

  def self.update_all_versions_counts
    Distro.find_each do |distro|
      distro.update_versions_count
    end
  end

  def self.update_all_total_downloads
    Distro.find_each do |distro|
      distro.update_total_downloads
    end
  end

  def self.missing_from_versions
    # Find distro_names in Version table that don't exist in Distro table
    Version.where.not(distro_name: [nil, ''])
           .group(:distro_name)
           .count
           .reject { |pretty_name, _count| exists?(pretty_name: pretty_name) }
           .sort_by { |_name, count| -count }
  end

  def self.guess_docker_image_from_name(distro_name)
    # Parse distro name to guess likely Docker Hub image (only Docker Hub, not other registries)
    name_lower = distro_name.downcase

    # Common patterns for Docker Hub official images
    patterns = {
      /^alpine linux v?(\d+\.\d+)/ => ->(m) { "alpine:#{m[1]}" },
      /^debian gnu\/linux (\d+)/ => ->(m) { "debian:#{m[1]}" },
      /^ubuntu (\d+\.\d+)/ => ->(m) { "ubuntu:#{m[1]}" },
      /^fedora.*?(\d+)/ => ->(m) { "fedora:#{m[1]}" },
      /^centos.*?(\d+)/ => ->(m) { "centos:#{m[1]}" },
      /^rocky linux (\d+)/ => ->(m) { "rockylinux:#{m[1]}" },
      /^almalinux (\d+)/ => ->(m) { "almalinux:#{m[1]}" },
      /^red hat.*?(\d+)/ => ->(m) { "redhat/ubi#{m[1]}" },
      /^oracle linux.*?(\d+)/ => ->(m) { "oraclelinux:#{m[1]}" },
      /^amazon linux (\d+)/ => ->(m) { "amazonlinux:#{m[1]}" },
      /^arch linux/ => ->(m) { "archlinux:latest" }
    }

    patterns.each do |pattern, builder|
      if match = name_lower.match(pattern)
        return builder.call(match)
      end
    end

    nil
  end

  def self.sync_from_github
    require 'fileutils'
    require 'tmpdir'

    Dir.mktmpdir do |tmp_dir|
      repo_path = File.join(tmp_dir, 'os-release')

      # Clone the repository
      system('git', 'clone', '--depth', '1', 'https://github.com/which-distro/os-release.git', repo_path, exception: true)

      # Find all os-release files
      os_release_files = Dir.glob(File.join(repo_path, '**', '*')).select do |file|
        File.file?(file) && !file.include?('.git')
      end

      os_release_files.each do |file_path|
        parse_and_create_distro(file_path)
      end

      # Update counts after syncing
      update_all_versions_counts
      update_all_total_downloads
    end
  end

  def self.parse_and_create_distro(file_path)
    content = File.read(file_path)

    # Skip empty files or non-os-release files
    return if content.strip.empty?
    return unless content.include?('NAME=') || content.include?('PRETTY_NAME=')

    attributes = parse_os_release(content)
    attributes[:raw_content] = content

    # Skip if no pretty_name (required field)
    return unless attributes[:pretty_name].present?

    # Generate slug
    slug = attributes[:pretty_name].to_s.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')

    # Find or create by slug
    distro = find_or_initialize_by(slug: slug)
    distro.assign_attributes(attributes)
    distro.save if distro.changed?
  rescue => e
    Rails.logger.error("Error parsing #{file_path}: #{e.message}")
  end

  def self.parse_os_release(content)
    attributes = {}

    content.each_line do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#')

      if line =~ /^([A-Z_]+)=(.+)$/
        key = $1
        value = $2.gsub(/^["']|["']$/, '') # Remove surrounding quotes

        case key
        when 'ID' then attributes[:id_field] = value
        when 'ID_LIKE' then attributes[:id_like] = value
        when 'NAME' then attributes[:name] = value
        when 'VERSION_ID' then attributes[:version_id] = value
        when 'PRETTY_NAME' then attributes[:pretty_name] = value
        when 'VERSION_CODENAME' then attributes[:version_codename] = value
        when 'VARIANT' then attributes[:variant] = value
        when 'VARIANT_ID' then attributes[:variant_id] = value
        when 'HOME_URL' then attributes[:home_url] = value
        when 'SUPPORT_URL' then attributes[:support_url] = value
        when 'BUG_REPORT_URL' then attributes[:bug_report_url] = value
        when 'DOCUMENTATION_URL' then attributes[:documentation_url] = value
        when 'LOGO' then attributes[:logo] = value
        when 'ANSI_COLOR' then attributes[:ansi_color] = value
        when 'CPE_NAME' then attributes[:cpe_name] = value
        when 'BUILD_ID' then attributes[:build_id] = value
        when 'IMAGE_ID' then attributes[:image_id] = value
        when 'IMAGE_VERSION' then attributes[:image_version] = value
        end
      end
    end

    attributes
  end
end
