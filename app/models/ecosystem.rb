class Ecosystem < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  def self.refresh_stats
    PackageUsage.group(:ecosystem).pluck(
      Arel.sql('ecosystem'),
      Arel.sql('COUNT(*) as count'),
      Arel.sql('SUM(downloads_count) as downloads')
    ).each do |ecosystem_name, packages_count, total_downloads|
      ecosystem = find_or_initialize_by(name: ecosystem_name)
      ecosystem.packages_count = packages_count
      ecosystem.total_downloads = total_downloads || 0
      ecosystem.save!
    end
  end
end
