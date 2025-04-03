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

    if params[:query].present?
      query = "%#{params[:query].downcase}%"
      scope = scope.where('LOWER(name) LIKE ? OR LOWER(description) LIKE ?', query, query)
    end

    @pagy, @packages = pagy_countless(scope)
    fresh_when(@packages, public: true)
  end


  def show
    @package = Package.find_by_name(params[:id])
    raise ActiveRecord::RecordNotFound unless @package
    fresh_when(@package, public: true)
  end
end