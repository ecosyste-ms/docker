class VersionsController < ApplicationController
  def index
    @package = Package.find_by_name(params[:package_id])
    redirect_to package_path(@package)
  end

  def show
    @package = Package.find_by_name(params[:package_id])
    raise ActiveRecord::RecordNotFound unless @package
    @version = @package.versions.where(number: params[:id]).includes(:dependencies).first
    raise ActiveRecord::RecordNotFound unless @version
    fresh_when(@version, public: true)
  end
end