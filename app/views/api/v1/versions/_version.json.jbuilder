json.extract! version, :number, :published_at, :last_synced_at, :created_at, :updated_at, :distro
json.version_url api_v1_package_version_url(version.package, version, format: :json)
json.dependencies version.dependencies, partial: 'api/v1/dependencies/dependency', as: :dependency
