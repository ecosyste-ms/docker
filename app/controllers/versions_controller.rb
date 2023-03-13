class VersionsController < ApplicationController
  def index
    @package = Package.find_by_name(params[:package_id])
    @versions = @package.versions
  end

  def show
    @package = Package.find_by_name(params[:package_id])
    @version = @package.versions.find_by_number(params[:id])
  end
end