class DependenciesController < ApplicationController
  def index
    @ecosystems = Dependency.group(:ecosystem).count.sort_by { |k, v| v }.reverse
  end

  def ecosystem
    @ecosystem = params[:ecosystem]
    @scope = Dependency.where(ecosystem: params[:ecosystem]).group(:package_name).count.sort_by { |k, v| v }.reverse
    @pagy, @dependencies = pagy_array(@scope)
  end

  def show
    @ecosystem = params[:ecosystem]
    @package_name = params[:id]
    @scope = Dependency.where(ecosystem: params[:ecosystem], package_name: params[:id]).includes(:package, :version)
    @total_downloads = Package.where(id: @scope.pluck(:package_id)).sum(:downloads)
    @pagy, @dependencies = pagy(@scope)
  end
end