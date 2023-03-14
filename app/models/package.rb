class Package < ApplicationRecord

  validates :name, presence: true, uniqueness: true

  has_many :versions

  def to_s
    name
  end

  def to_param
    name
  end

  def self.sync_popular
    page = (REDIS.get('next_popular_page') || 1).to_i
    p page
    url = "https://packages.ecosyste.ms/api/v1/registries/hub.docker.com/packages?sort=downloads&order=desc&limit=100&page=#{page}"
    response = Faraday.get(url)
    return unless response.success?
    json = JSON.parse(response.body)
    json.each do |package|
      next if package['downloads'].nil?
      p = Package.find_or_create_by(name: package["name"])
      p.sync_latest_release
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
    versions.sort_by(&:published_at).last
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
end
