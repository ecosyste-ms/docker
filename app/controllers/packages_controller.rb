class PackagesController < ApplicationController
  def index
    scope = Package.where(has_sbom: true)
    
    sort = params[:sort].presence || 'latest_release_published_at'
    if params[:order] == 'asc'
      scope = scope.order(Arel.sql(sort).asc.nulls_last)
    else
      scope = scope.order(Arel.sql(sort).desc.nulls_last)
    end
    
    @pagy, @packages = pagy_countless(scope)
    fresh_when(@packages, public: true)
  end

  def show
    @package = Package.find_by_name(params[:id])
    raise ActiveRecord::RecordNotFound unless @package
    fresh_when(@package, public: true)
    @pagy, @versions = pagy_countless(@package.versions.order('published_at DESC'))
  end
end