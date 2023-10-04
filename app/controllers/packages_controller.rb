class PackagesController < ApplicationController
  def index
    scope = Package.where(has_sbom: true)
    
    sort = params[:sort].presence || 'last_synced_at'
    if params[:order] == 'asc'
      scope = scope.order(Arel.sql(sort).asc.nulls_last)
    else
      scope = scope.order(Arel.sql(sort).desc.nulls_last)
    end
    
    @pagy, @packages = pagy_countless(scope)
  end

  def show
    @package = Package.find_by_name(params[:id])
    @pagy, @versions = pagy_countless(@package.versions.order('published_at DESC'))
  end
end