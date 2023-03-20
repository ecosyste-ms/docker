class PackagesController < ApplicationController
  def index
    scope = Package.where(has_sbom: true).where('dependencies_count > 0')
    
    sort = params[:sort].presence || 'last_synced_at'
    if params[:order] == 'asc'
      scope = scope.order(Arel.sql(sort).asc.nulls_last)
    else
      scope = scope.order(Arel.sql(sort).desc.nulls_last)
    end
    
    @pagy, @packages = pagy(scope)
  end

  def show
    @package = Package.find_by_name(params[:id])
    @pagy, @versions = pagy(@package.versions.select(:package_id,:number,:published_at,:last_synced_at))
  end
end