class PackagesController < ApplicationController
  def index
    @scope = Package.all
    @pagy, @packages = pagy(@scope)
  end

  def show
    @package = Package.find_by_name(params[:id])
    @pagy, @versions = pagy(@package.versions)
  end
end