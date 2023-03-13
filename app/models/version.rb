class Version < ApplicationRecord

  validates :number, presence: true
  validates_uniqueness_of :number, scope: :package_id, case_sensitive: false

  belongs_to :package

  def to_s
    number
  end

  def to_param
    number
  end
  
  def parse_sbom_async
    ParseSbomWokrker.perform_async(self.id)
  end

  def parse_sbom
    results = `syft #{self.package.name}:#{self.number} --quiet --output syft-json`
    json = JSON.parse(results)
    update(sbom: json, last_synced_at: Time.now)
  rescue => e
    json = nil
    update(sbom: json, last_synced_at: Time.now)
  end

  def purls
    return [] if sbom.nil?
    sbom["artifacts"].map do |artifact|
      artifact["purl"]
    end.sort
  end
end
