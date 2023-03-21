class PackageUsagesController < ApplicationController
  def index
    @ecosystems = PackageUsage.group(:ecosystem).count.sort_by { |k, v| v }.reverse
  end

  def ecosystem
    @ecosystem = params[:ecosystem]
    @scope = PackageUsage.where(ecosystem: @ecosystem).order('dependents_count desc')
    @pagy, @dependencies = pagy(@scope)
  end

  def show
    @ecosystem = params[:ecosystem]
    @package_name = params[:id]
    @package_usage = PackageUsage.find_or_create_by_ecosystem_and_name(@ecosystem, @package_name)
    @scope = @package_usage.dependencies.includes(:package)
    @pagy, @dependencies = pagy(@scope.order('package_id asc'))
  end
end