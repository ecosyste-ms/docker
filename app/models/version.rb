# TODO: After SBOM migration is complete, remove:
# - The sbom column references in this file (marked with "Remove after migration" comments)
# - The migration-specific methods at the bottom of this file
# - The dual-mode logic in parse_sbom method

class Version < ApplicationRecord

  validates :number, presence: true
  validates_uniqueness_of :number, scope: :package_id, case_sensitive: false

  belongs_to :package
  counter_culture :package
  has_many :dependencies, dependent: :delete_all
  has_one :sbom_record, class_name: 'Sbom', dependent: :destroy
  
  # TODO: Remove this scope after SBOM migration is complete
  scope :needs_sbom_migration, -> { 
    where.not(sbom: nil)
         .left_joins(:sbom_record)
         .where(sboms: { id: nil })
  }

  def to_s
    number
  end

  def to_param
    number
  end
  
  def distro
    # Try cached field first (available after migration starts)
    return distro_name if distro_name.present?
    
    # Fall back to JSON column (remove this after migration)
    return nil if sbom.nil?
    sbom['distro']['prettyName']
  end

  def syft_version
    # Try cached field first (available after migration starts)
    return read_attribute(:syft_version) if read_attribute(:syft_version).present?
    
    # Fall back to JSON column (remove this after migration)
    return nil if sbom.nil?
    sbom['descriptor']['version']
  end

  def outdated?
    return false if syft_version.nil?
    syft_version != Package.syft_version
  end
  
  def has_sbom?
    # After migration: only check sbom_record
    # During migration: check both
    # Before migration: only check sbom column
    sbom_record.present? || sbom.present?
  end
  
  def sbom_data
    # After migration: only use sbom_record
    # During migration: prefer sbom_record if available
    # Before migration: use sbom column
    return sbom_record.data if sbom_record.present?
    sbom
  end

  def parse_sbom_async
    ParseSbomWorker.perform_async(self.id)
  end

  def parse_sbom
    results = `syft #{self.package.name}:#{self.number} --quiet --output syft-json`
    json = JSON.parse(results)
    
    transaction do
      # Always update cached fields (added in migration)
      self.distro_name = json.dig('distro', 'prettyName')
      self.syft_version = json.dig('descriptor', 'version')
      self.artifacts_count = extract_purls_from_json(json).count
      self.last_synced_at = Time.now
      
      # Try to save to new structure first
      sbom_created_or_updated = false
      begin
        if sbom_record.present?
          sbom_record.update!(data: json)
        else
          create_sbom_record!(data: json)
        end
        sbom_created_or_updated = true
      rescue => e
        # If new structure fails, we'll fall back to old structure
        Rails.logger.error "Failed to save to sbom_record: #{e.message}"
      end
      
      # Handle old structure based on new structure success (remove this block after migration)
      if sbom_created_or_updated
        # Successfully saved to new structure, clear old column
        self.sbom = nil
      else
        # Failed to save to new structure, update old column
        self.sbom = json
      end
      
      save!
      
      package.update!(
        has_sbom: true, 
        last_synced_at: Time.now, 
        dependencies_count: self.artifacts_count
      )
      
      save_dependencies
    end
  rescue => e
    puts e
    # On error, only update the timestamp to track the failed attempt
    # Keep existing SBOM data if present
    update(last_synced_at: Time.now)
  end
  
  private
  
  def extract_purls_from_json(json)
    return [] unless json && json['artifacts']
    json['artifacts'].map { |a| a['purl'] }.sort.reject(&:blank?).uniq
  end

  public
  
  def purls
    # After migration: only use sbom_record
    # During migration: prefer sbom_record if available  
    # Before migration: use sbom column
    return sbom_record.purls if sbom_record.present?
    
    # Fall back to JSON column (remove this block after migration)
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
  
  # ==========================================
  # TODO: Remove all methods below after SBOM migration is complete
  # These are temporary methods for the migration process
  # ==========================================

  def migrate_sbom_to_table
    return false unless sbom.present? && sbom_record.blank?
    
    transaction do
      # Save the SBOM data before we clear it
      sbom_data = sbom
      
      # Update cached fields
      self.distro_name = sbom_data.dig('distro', 'prettyName')
      self.syft_version = sbom_data.dig('descriptor', 'version') 
      self.artifacts_count = extract_purls_from_json(sbom_data).count
      
      # Create new sbom record
      create_sbom_record!(data: sbom_data)
      
      # Clear old column after successful creation
      self.sbom = nil
      save!
      
      true
    end
  rescue => e
    Rails.logger.error "Failed to migrate SBOM for version #{id}: #{e.message}"
    false
  end
    
  def self.sbom_migration_stats
    total_versions = count
    total_with_sbom = where.not(sbom: nil).count
    migrated = joins(:sbom_record).count
    to_migrate = needs_sbom_migration.count
    
    {
      total_versions: total_versions,
      total_with_sbom: total_with_sbom,
      migrated: migrated,
      to_migrate: to_migrate,
      progress_percent: total_with_sbom > 0 ? (migrated.to_f / total_with_sbom * 100).round(2) : 0
    }
  end
end
