class VersionsController < ApplicationController
  def index
    if params[:package_id]
      @package = Package.find_by_name(params[:package_id])
      redirect_to package_path(@package)
    elsif params[:distro_id]
      @distro = Distro.find_by_slug(params[:distro_id])
      raise ActiveRecord::RecordNotFound unless @distro
      @scope = @distro.versions.includes(:package)
      @pagy, @versions = pagy_countless(@scope.order('published_at DESC NULLS LAST'))
      fresh_when(@versions, public: true)
    end
  end

  def show
    @package = Package.find_by_name(params[:package_id])
    raise ActiveRecord::RecordNotFound unless @package
    @version = @package.versions.where(number: params[:id]).includes(:dependencies).first
    raise ActiveRecord::RecordNotFound unless @version
    fresh_when(@version, public: true)
  end
end