class Api::V1::PackageUsagesController < Api::V1::ApplicationController
  def index
    sort = params[:sort] || 'packages_count'
    order = params[:order] || 'desc'

    allowed_sorts = ['name', 'packages_count', 'total_downloads']
    sort = 'packages_count' unless allowed_sorts.include?(sort)
    order = 'desc' unless ['asc', 'desc'].include?(order)

    @ecosystems = Ecosystem.order("#{sort} #{order}").pluck(:name, :packages_count, :total_downloads)
    expires_in 1.day, public: true
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

    @pagy, @package_usages = pagy_countless(scope)
    raise ActiveRecord::RecordNotFound unless @package_usages.any?
    fresh_when(@package_usages, public: true)
  end

  def show
    @ecosystem = params[:ecosystem]
    @package_usage = PackageUsage.where(ecosystem: @ecosystem).find_by_name!(params[:id])
    fresh_when(@package_usage, public: true)
  end

  def dependencies
    @ecosystem = params[:ecosystem]
    @package_usage = PackageUsage.where(ecosystem: @ecosystem).find_by_name!(params[:name])
    @scope = @package_usage.dependencies.includes(:package, :version)
    @pagy, @dependencies = pagy_countless(@scope)
  end
end