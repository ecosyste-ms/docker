class VersionsController < ApplicationController
  def index
    @package = Package.find_by_name(params[:package_id])
    redirect_to package_path(@package)
  end

  def show
    @package = Package.find_by_name(params[:package_id])
    @version = @package.versions.select(:package_id,:number,:published_at,:last_synced_at).where(number: params[:id]).includes(:dependencies).references(:dependencies).first
  end
end