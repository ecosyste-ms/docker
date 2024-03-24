class Dependency < ApplicationRecord
  belongs_to :version
  belongs_to :package

  validates_presence_of :package_name, :version_id, :requirements, :ecosystem, :purl, :package_id

  scope :ecosystem, ->(ecosystem) { where(ecosystem: ecosystem.downcase) }

  def package_url
    PackageURL.parse(purl)
  end

  def to_param
    package_name.gsub(/\s+/, "")
  end
end
