class PackageUsagesController < ApplicationController
  def index
    @ecosystems = PackageUsage.group(:ecosystem).count.sort_by { |k, v| v }.reverse
  end

  def ecosystem
    # todo redirect to correct ecosystem if different
    @ecosystem = PackageUsage.ecosystem_to_type(params[:ecosystem])
    @scope = PackageUsage.where(ecosystem: @ecosystem).order('dependents_count desc')
    @pagy, @dependencies = pagy(@scope)
    raise ActiveRecord::RecordNotFound unless @dependencies.any?
  end

  def show
    # todo redirect to correct ecosystem if different
    @ecosystem = PackageUsage.ecosystem_to_type(params[:ecosystem])
    @package_name = params[:id]
    @package_usage = PackageUsage.find_or_create_by_ecosystem_and_name(@ecosystem, @package_name)
    raise ActiveRecord::RecordNotFound unless @package_usage
    @scope = @package_usage.dependencies.includes(:package)
    @pagy, @dependencies = pagy(@scope.order('package_id asc'))
  end
end