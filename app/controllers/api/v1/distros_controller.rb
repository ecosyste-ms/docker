class Api::V1::DistrosController < Api::V1::ApplicationController
  def index
    scope = Distro.all
    scope = scope.created_after(params[:created_after]) if params[:created_after].present?
    scope = scope.updated_after(params[:updated_after]) if params[:updated_after].present?

    if params[:sort].present? || params[:order].present?
      sort = params[:sort] || 'pretty_name'
      order = params[:order] || 'asc'
      sort_options = sort.split(',').zip(order.split(',')).to_h
      scope = scope.order(sort_options)
    end

    if params[:query].present?
      query = "%#{params[:query].strip.downcase}%"
      scope = scope.where('LOWER(pretty_name) LIKE ? OR LOWER(name) LIKE ? OR LOWER(id_field) LIKE ?', query, query, query)
    end

    @pagy, @distros = pagy_countless(scope)
    fresh_when(@distros, public: true)
  end

  def show
    @distro = Distro.find_by_slug(params[:id])
    raise ActiveRecord::RecordNotFound unless @distro
    fresh_when(@distro, public: true)
  end
end
