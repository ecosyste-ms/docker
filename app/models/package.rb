class Package < ApplicationRecord

  validates :name, presence: true, uniqueness: true

  has_many :versions, dependent: :delete_all
  has_many :dependencies, dependent: :delete_all


  def to_s
    name
  end

  def to_param
    name
  end

  def sync
    response = Faraday.get(packages_api_url)
    return unless response.success?
    json = JSON.parse(response.body)
    self.update(
      versions_count: versions.count,
      description: json["description"],
      downloads: json["downloads"],
      repository_url: json["repository_url"]
    )
  end

  def self.sync_popular
    page = (REDIS.get('next_popular_page') || 1).to_i
    url = "https://packages.ecosyste.ms/api/v1/registries/hub.docker.com/packages?sort=downloads&order=desc&limit=50&page=#{page}"
    response = Faraday.get(url)
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
      p.sync_latest_release rescue nil
    end
    REDIS.set('next_popular_page', page + 1)
  end

  def packages_api_url
    "https://packages.ecosyste.ms/api/v1/registries/hub.docker.com/packages/#{name}"
  end

  def packages_html_url
    "https://packages.ecosyste.ms/registries/hub.docker.com/packages/#{name}"
  end

  def latest_release
    version.sort_by(&:published_at).last
  end

  def sync_latest_release
    response = Faraday.get(packages_api_url)
    return unless response.success?
    json = JSON.parse(response.body)

    number = json["latest_release_number"] || "latest"
    published_at = json["latest_release_published_at"]

    return if latest_release_published_at == Time.parse(published_at)

    version = versions.find_or_create_by(number: number)
    version.published_at = published_at
    version.save
    version.parse_sbom_async

    self.update(
      latest_release_number: number,
      latest_release_published_at: published_at
    )
  end

  def self.syft_version
    @syft_version ||= `syft --version`.strip.split(' ').last
  end
end
