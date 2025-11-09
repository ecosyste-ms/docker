class PackageUsagesController < ApplicationController
  def index
    sort = params[:sort] || 'packages_count'
    order = params[:order] || 'desc'

    allowed_sorts = ['name', 'packages_count', 'total_downloads']
    sort = 'packages_count' unless allowed_sorts.include?(sort)
    order = 'desc' unless ['asc', 'desc'].include?(order)

    @ecosystems = Ecosystem
      .order("#{sort} #{order}")
      .pluck(:name, :packages_count, :total_downloads)
      .map { |name, count, downloads| { ecosystem: name, count: count, downloads: downloads } }

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