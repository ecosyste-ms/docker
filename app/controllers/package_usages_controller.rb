class PackageUsagesController < ApplicationController
  def index
    @ecosystems = PackageUsage.group(:ecosystem).count.sort_by { |k, v| v }.reverse

    @ecosystems = @ecosystems.map do |ecosystem, count|
      {
        ecosystem: ecosystem,
        count: count,
        downloads: PackageUsage.where(ecosystem: ecosystem).sum(:downloads_count)
      }
    end

    expires_in 1.day, public: true
  end

  def ecosystem
    # todo redirect to correct ecosystem if different
    @ecosystem = PackageUsage.ecosystem_to_type(params[:ecosystem])
    @scope = PackageUsage.where(ecosystem: @ecosystem).order('dependents_count desc')
    @pagy, @dependencies = pagy_countless(@scope)
    raise ActiveRecord::RecordNotFound unless @dependencies.any?
    fresh_when(@dependencies, public: true)
  end

  def show
    # todo redirect to correct ecosystem if different
    @ecosystem = PackageUsage.ecosystem_to_type(params[:ecosystem])
    @package_name = params[:id]
    @package_usage = PackageUsage.find_or_create_by_ecosystem_and_name(@ecosystem, @package_name)
    raise ActiveRecord::RecordNotFound unless @package_usage
    fresh_when(@package_usage, public: true)
    @dependencies = @package_usage.dependencies.includes(:package).limit(100)
  end
end