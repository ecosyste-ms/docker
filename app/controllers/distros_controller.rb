class DistrosController < ApplicationController
  def index
    scope = Distro.all

    if params[:query].present?
      query = "%#{params[:query].downcase}%"
      scope = scope.where('LOWER(pretty_name) LIKE ? OR LOWER(name) LIKE ? OR LOWER(id_field) LIKE ?', query, query, query)
    end

    @distro_groups = Distro.grouped_and_deduped(scope.where(discontinued: false))
    @discontinued_groups = Distro.grouped_and_deduped(scope.where(discontinued: true))
    @ungrouped_distros = scope.where(discontinued: false, slug: [nil, ''], id_field: [nil, ''], name: [nil, ''])
                              .select(:id, :slug, :pretty_name, :name, :id_field, :version_id,
                                      :version_codename, :variant, :updated_at)
                              .to_a
  end

  def show
    @distro = Distro.find_by_slug(params[:id])
    raise ActiveRecord::RecordNotFound unless @distro
    fresh_when(@distro, public: true)
  end
end
