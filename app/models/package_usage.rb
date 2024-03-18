class PackageUsage < ApplicationRecord
  validates :ecosystem, presence: true
  validates :name, presence: true

  def to_s
    name
  end

  def to_param
    name.gsub(/\s+/, "")
  end

  def dependencies
    Dependency.where(ecosystem: ecosystem, package_name: name)
  end

  def fetch_dependents_count
    @dependents_count ||= Dependency.where(ecosystem: ecosystem, package_name: name).distinct.count(:package_id)
  end

  def fetch_downloads_count
    @downloads_count ||= Dependency.where(ecosystem: ecosystem, package_name: name).distinct(:package_id).joins(:package).sum('packages.downloads')
  end

  def update_counts
    update_columns({dependents_count: fetch_dependents_count, downloads_count: fetch_downloads_count})
  end

  def self.find_or_create_by_ecosystem_and_name(ecosystem, name)
    pu = PackageUsage.find_by(ecosystem: ecosystem, name: name)
    if pu.nil?
      d = Dependency.where(ecosystem: ecosystem, package_name: name).first
      return nil if d.nil?
      pu = PackageUsage.create(ecosystem: ecosystem, name: name)
      pu.update_counts if pu.persisted?
    end
    
    pu
  end

  def self.create_all
    Dependency.select(:ecosystem, :package_name).distinct.each do |d|
      find_or_create_by_ecosystem_and_name(d.ecosystem, d.package_name)
    end
  end

  def self.update_all_counts
    PackageUsage.create_all
    PackageUsage.all.find_each(&:update_counts)
  end

  def self.ecosystem_to_type(ecosystem)
    case ecosystem
    when 'go'
      'golang'
    when 'actions'
      'github'
    when 'adelie'
      'apk'
    when 'alpine'
      'apk'
    when 'postmarketos'
      'apk'
    when 'packagist'
      'composer'
    when 'rubygems'
      'gem'
    when 'dart'
      # temporary as everything should end up as dart eventually
      'pub'
    else
      ecosystem
    end
  end
end
