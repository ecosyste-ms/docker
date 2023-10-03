class Version < ApplicationRecord

  validates :number, presence: true
  validates_uniqueness_of :number, scope: :package_id, case_sensitive: false

  belongs_to :package
  counter_culture :package
  has_many :dependencies, dependent: :delete_all

  def to_s
    number
  end

  def to_param
    number
  end
  
  def distro
    return nil if sbom.nil?
    sbom['distro']['prettyName']
  end

  def syft_version
    return nil if sbom.nil?
    sbom['descriptor']['version']
  end

  def outdated?
    return false if syft_version.nil?
    syft_version != package.syft_version
  end

  def parse_sbom_async
    ParseSbomWorker.perform_async(self.id)
  end

  def parse_sbom
    results = `syft #{self.package.name}:#{self.number} --quiet --output syft-json`
    json = JSON.parse(results)
    self.sbom = json
    update(sbom: json, last_synced_at: Time.now)
    package.update(has_sbom: true, last_synced_at: Time.now, dependencies_count: purls.length)
    save_dependencies
  rescue => e
    json = nil
    update(sbom: json, last_synced_at: Time.now)
  end

  def purls
    return [] if sbom.nil?
    sbom["artifacts"].map do |artifact|
      # TODO syft incorretly lists submodules as different packages: eg @stdlib/assert/contains 
      artifact["purl"]
    end.sort.reject(&:blank?).uniq
  end

  def save_dependencies
    dependencies.delete_all
    deps = purls.map do |purl|
      begin
        pkg = PackageURL.parse(purl)

        {
          version_id: id,
          package_id: package.id, 
          ecosystem: pkg.type, 
          package_name: [pkg.namespace,pkg.name].compact.join(pkg.type == 'maven' ? ':' : '/'), 
          requirements: pkg.version || '*', 
          purl: purl
        }
      rescue
        nil
      end
    end.compact
    return if deps.empty?

    Dependency.insert_all(deps)
  end
end
