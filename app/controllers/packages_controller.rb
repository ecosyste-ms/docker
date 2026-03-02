class PackagesController < ApplicationController
  def index
    scope = Package.where(has_sbom: true)

    sort = sanitize_sort(Package.sortable_columns, default: 'last_synced_at')
    if params[:order] == 'asc'
      scope = scope.order(sort.asc.nulls_last)
    else
      scope = scope.order(sort.desc.nulls_last)
    end

    if params[:query].present?
      query = "%#{params[:query].downcase}%"
      scope = scope.where('LOWER(name) LIKE ? OR LOWER(description) LIKE ?', query, query)
    end

    @pagy, @packages = pagy_countless(scope)

    # Stats for homepage - cache for 1 day
    @stats = Rails.cache.fetch('homepage_stats', expires_in: 1.day) do
      {
        total_packages: Package.fast_total,
        total_versions: Version.fast_total,
        total_distros: Distro.fast_total,
        total_dependencies: Dependency.fast_total,
        total_ecosystems: PackageUsage.distinct.count(:ecosystem),
        total_sboms: Sbom.fast_total
      }
    end

    fresh_when(@packages, public: true)
  end

  def show
    @package = Package.find_by_name(params[:id])
    raise ActiveRecord::RecordNotFound unless @package
    fresh_when(@package, public: true)
    @pagy, @versions = pagy_countless(@package.versions.order('published_at DESC'))
  end
end