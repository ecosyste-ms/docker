class Sbom < ApplicationRecord
  belongs_to :version
  
  validates :data, presence: true
  validates :version_id, uniqueness: true
  
  before_save :cache_fields
  
  def distro
    data.dig('distro', 'prettyName')
  end
  
  def descriptor_version
    data.dig('descriptor', 'version')
  end
  
  def artifacts
    data['artifacts'] || []
  end
  
  def purls
    artifacts.map { |artifact| artifact['purl'] }
      .sort
      .reject(&:blank?)
      .uniq
  end
  
  private
  
  def cache_fields
    self.distro_name = distro
    self.syft_version = descriptor_version
    self.artifacts_count = purls.count
  end
end