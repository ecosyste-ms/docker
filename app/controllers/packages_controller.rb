class PackagesController < ApplicationController
  def index
    @scope = Package.where(has_sbom: true).where.not(dependencies_count: nil).order('packages.last_synced_at DESC')
    @pagy, @packages = pagy(@scope)
  end

  def show
    @package = Package.find_by_name(params[:id])
    @pagy, @versions = pagy(@package.versions)
  end
end