class Version < ApplicationRecord

  validates :number, presence: true
  validates_uniqueness_of :number, scope: :package_id, case_sensitive: false

  belongs_to :package
  counter_culture :package
  has_many :dependencies, dependent: :delete_all
  has_one :sbom_record, class_name: 'Sbom', dependent: :destroy

  def to_s
    number
  end

  def to_param
    number
  end
  
  def distro
    distro_name
  end

  def distro_record
    return nil unless distro_name.present?
    Distro.find_by(pretty_name: distro_name)
  end

  def distro_data
    return nil unless sbom_data.present?
    sbom_data.dig('distro')
  end

  def syft_version
    read_attribute(:syft_version)
  end

  def outdated?
    return false if syft_version.nil?
    syft_version != Package.syft_version
  end
  
  def has_sbom?
    sbom_record.present?
  end
  
  def sbom_data
    sbom_record&.data
  end

  def parse_sbom_async
    ParseSbomWorker.perform_async(self.id)
  end

  def parse_sbom
    require 'open3'
    image_name = "#{self.package.name}:#{self.number}"

    stdout, status = Open3.capture2('timeout', '15m', 'syft', image_name, '--quiet', '--output', 'syft-json')

    if status.exitstatus == 124
      raise Timeout::Error, "Syft timed out after 15 minutes"
    elsif !status.success?
      raise "Syft command failed with status #{status.exitstatus}"
    end

    json = JSON.parse(stdout)

    transaction do
      self.distro_name = json.dig('distro', 'prettyName')
      self.syft_version = json.dig('descriptor', 'version')
      self.artifacts_count = extract_purls_from_json(json).count
      self.last_synced_at = Time.now
      self.last_synced_error = nil

      if sbom_record.present?
        sbom_record.update!(data: json)
      else
        create_sbom_record!(data: json)
      end

      save!

      package.update!(
        has_sbom: true,
        last_synced_at: Time.now,
        dependencies_count: self.artifacts_count
      )

      save_dependencies
    end
  rescue Timeout::Error => e
    update(last_synced_at: Time.now, last_synced_error: "Timeout after 15 minutes")
  rescue => e
    update(last_synced_at: Time.now, last_synced_error: "#{e.class}: #{e.message}")
  end
  
  private
  
  def extract_purls_from_json(json)
    return [] unless json && json['artifacts']
    json['artifacts'].map { |a| a['purl'] }.sort.reject(&:blank?).uniq
  end

  public
  
  def purls
    sbom_record&.purls || []
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
          package_name: [pkg.namespace,pkg.name.gsub(/\s+/, "")].compact.join(pkg.type == 'maven' ? ':' : '/'), 
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

  def backfill_distro_name
    return false if distro_name.present?
    return false unless has_sbom?

    data = sbom_data
    return false if data.nil?

    extracted_name = data.dig('distro', 'prettyName')
    return false if extracted_name.nil?

    update_column(:distro_name, extracted_name)
    true
  rescue => e
    Rails.logger.error "Failed to backfill distro_name for version #{id}: #{e.message}"
    false
  end

  def self.backfill_all_distro_names
    needing_backfill = where(distro_name: nil).includes(:sbom_record)

    total = needing_backfill.count
    success_count = 0

    needing_backfill.find_each do |version|
      success_count += 1 if version.backfill_distro_name
    end

    {
      total: total,
      backfilled: success_count,
      failed: total - success_count
    }
  end
    
end
