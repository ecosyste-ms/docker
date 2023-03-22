class Api::V1::PackageUsagesController < Api::V1::ApplicationController
  def index
    @ecosystems = PackageUsage.group(:ecosystem).count.sort_by{|e,c| -c }
  end

  def ecosystem
    @ecosystem = params[:ecosystem]
    scope = PackageUsage.where(ecosystem: @ecosystem)
    scope = scope.created_after(params[:created_after]) if params[:created_after].present?
    scope = scope.updated_after(params[:updated_after]) if params[:updated_after].present?

    if params[:sort].present? || params[:order].present?
      sort = params[:sort] || 'updated_at'
      order = params[:order] || 'desc'
      sort_options = sort.split(',').zip(order.split(',')).to_h
      scope = scope.order(sort_options)
    end

    @pagy, @package_usages = pagy(scope)
    raise ActiveRecord::RecordNotFound unless @package_usages.any?
  end

  def show
    @ecosystem = params[:ecosystem]
    @package_usage = PackageUsage.where(ecosystem: @ecosystem).find_by_name!(params[:id])
  end

  def dependencies
    @ecosystem = params[:ecosystem]
    @package_usage = PackageUsage.where(ecosystem: @ecosystem).find_by_name!(params[:name])
    @scope = @package_usage.dependencies.includes(:package, :version)
    @pagy, @dependencies = pagy(@scope)
  end
end