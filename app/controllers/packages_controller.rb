class PackagesController < ApplicationController
  def index
    @scope = Package.where(has_sbom: true).where('dependencies_count > 0').order('packages.last_synced_at DESC')
    @pagy, @packages = pagy(@scope)
  end

  def show
    @package = Package.find_by_name(params[:id])
    @pagy, @versions = pagy(@package.versions)
  end
end