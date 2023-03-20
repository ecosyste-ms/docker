class DependenciesController < ApplicationController
  def index
    @ecosystems = PackageUsage.group(:ecosystem).count.sort_by { |k, v| v }.reverse
  end

  def ecosystem
    @ecosystem = params[:ecosystem]
    @scope = PackageUsage.where(ecosystem: @ecosystem).order('dependents_count desc')
    @pagy, @dependencies = pagy_array(@scope)
  end

  def show
    @ecosystem = params[:ecosystem]
    @package_name = params[:id]
    @package_usage = PackageUsage.find_or_create_by_ecosystem_and_name(@ecosystem, @package_name)
    @scope = @package_usage.dependencies.includes(:package, :version)
    @total_downloads = Package.where(id: @scope.pluck(:package_id).uniq).sum(:downloads)
    @pagy, @dependencies = pagy(@scope.order('package_id asc'))
  end
end