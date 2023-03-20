class Api::V1::PackagesController < Api::V1::ApplicationController
  def index
    scope = Package.all
    scope = scope.created_after(params[:created_after]) if params[:created_after].present?
    scope = scope.updated_after(params[:updated_after]) if params[:updated_after].present?

    if params[:sort].present? || params[:order].present?
      sort = params[:sort] || 'updated_at'
      order = params[:order] || 'desc'
      sort_options = sort.split(',').zip(order.split(',')).to_h
      scope = scope.order(sort_options)
    end

    @pagy, @packages = pagy(scope)
  end


  def show
    @package = Package.find_by_name(params[:id])
  end
end