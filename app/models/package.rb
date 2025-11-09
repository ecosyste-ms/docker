class Package < ApplicationRecord

  validates :name, presence: true, uniqueness: true

  has_many :versions, dependent: :delete_all
  has_many :dependencies, dependent: :delete_all

  scope :active, -> { where(status: nil) }
  scope :created_after, ->(time) { where('created_at >= ?', time) }
  scope :updated_after, ->(time) { where('updated_at >= ?', time) }

  def to_s
    name
  end

  def to_param
    name
  end

  def sync(all_versions: false)
    response = Faraday.get(packages_api_url) do |req|
      req.headers['X-API-Key'] = ENV['ECOSYSTEMS_API_KEY'] if ENV['ECOSYSTEMS_API_KEY']
    end
    return unless response.success?
    json = JSON.parse(response.body)
    self.update(
      versions_count: versions.count,
      description: json["description"],
      downloads: json["downloads"],
      repository_url: json["repository_url"],
      last_synced_at: Time.now,
      status: json["status"]
    )

    if all_versions
      sync_all_versions
    else
      sync_latest_release
    end
  end

  def sync_async
    SyncPackageWorker.perform_async(self.id)
  end

  def self.sync_popular
    page = (REDIS.get('next_popular_page') || 1).to_i
    url = "https://packages.ecosyste.ms/api/v1/registries/hub.docker.com/packages?sort=downloads&order=desc&limit=50&page=#{page}"
    response = Faraday.get(url) do |req|
      req.headers['X-API-Key'] = ENV['ECOSYSTEMS_API_KEY'] if ENV['ECOSYSTEMS_API_KEY']
    end
    return unless response.success?
    json = JSON.parse(response.body)
    json.each do |package|
      next if package['downloads'].nil?
      next if package['status'].present?
      if package['downloads'] == 0
        page = 0
        break 
      end
      p = Package.find_or_create_by(name: package["name"])
      p.update({
        description: package["description"],
        downloads: package["downloads"],
        repository_url: package["repository_url"]
      })
      p.sync rescue nil
    end
    REDIS.set('next_popular_page', page + 1)
  end

  def self.resync_outdated
    Package.active.order('last_synced_at ASC').limit(200).each(&:sync_async)
  end

  def packages_api_url
    "https://packages.ecosyste.ms/api/v1/registries/hub.docker.com/packages/#{name}"
  end

  def packages_html_url
    "https://packages.ecosyste.ms/registries/hub.docker.com/packages/#{name}"
  end

  def latest_release
    versions.order('published_at DESC nulls last, created_at desc').first
  end

  def sync_latest_release
    response = Faraday.get(packages_api_url) do |req|
      req.headers['X-API-Key'] = ENV['ECOSYSTEMS_API_KEY'] if ENV['ECOSYSTEMS_API_KEY']
    end
    return unless response.success?
    json = JSON.parse(response.body)

    number = json["latest_release_number"] || "latest"
    published_at = json["latest_release_published_at"]

    if latest_release_published_at && published_at && latest_release_published_at == Time.parse(published_at)
      latest_release.parse_sbom_async if latest_release.outdated?
      return
    end

    version = versions.find_or_create_by(number: number)
    version.published_at = published_at
    version.save
    version.parse_sbom_async

    self.update(
      latest_release_number: number,
      latest_release_published_at: published_at,
      last_synced_at: Time.now
    )
  end

  def sync_all_versions(limit: 100, parse_sbom: false)
    page = 1
    version_ids_to_parse = []

    loop do
      url = "#{packages_api_url}/versions?page=#{page}&per_page=#{limit}"
      response = Faraday.get(url) do |req|
        req.headers['X-API-Key'] = ENV['ECOSYSTEMS_API_KEY'] if ENV['ECOSYSTEMS_API_KEY']
      end

      break unless response.success?

      versions_data = JSON.parse(response.body)
      break if versions_data.empty?

      # Prepare data for upsert
      now = Time.current
      version_records = versions_data.map do |version_data|
        {
          package_id: id,
          number: version_data['number'],
          published_at: version_data['published_at'],
          created_at: now,
          updated_at: now
        }
      end

      # Upsert all versions in a single query
      Version.upsert_all(
        version_records,
        unique_by: [:package_id, :number],
        update_only: [:published_at]
      )

      # If parse_sbom is requested, find versions that need parsing
      if parse_sbom
        version_numbers = versions_data.map { |v| v['number'] }
        versions_needing_sbom = versions.where(number: version_numbers)
                                        .left_joins(:sbom_record)
                                        .where('sboms.id IS NULL OR versions.syft_version != ?', Package.syft_version)

        version_ids_to_parse.concat(versions_needing_sbom.pluck(:id))
      end

      page += 1
    end

    # Update versions_count since upsert_all bypasses counter_culture
    update_column(:versions_count, versions.count)

    # Queue SBOM parsing jobs if requested
    if parse_sbom && version_ids_to_parse.any?
      version_ids_to_parse.each do |version_id|
        ParseSbomWorker.perform_async(version_id)
      end
    end
  end

  def self.syft_version
    @syft_version ||= `syft --version`.strip.split(' ').last
  end

  def self.ensure_popular_have_sboms(limit: 1000)
    processed = 0
    enqueued = 0
    skipped = 0

    packages = where(has_sbom: false).where.not(downloads: nil).order(downloads: :desc)
    packages = packages.limit(limit) if limit

    packages.each do |package|
      processed += 1

      version = if package.latest_release_number.present?
                  package.versions.find_by(number: package.latest_release_number)
                else
                  package.versions.first
                end

      if version
        version.parse_sbom_async
        enqueued += 1
        print "+"
      else
        skipped += 1
        print "S"
      end

      if processed % 100 == 0
        puts "\nProcessed: #{processed}, Enqueued: #{enqueued}, Skipped: #{skipped}"
      end
    end

    puts "\n=== Complete ==="
    {
      total_processed: processed,
      enqueued_for_parsing: enqueued,
      skipped_no_versions: skipped
    }
  end
end
