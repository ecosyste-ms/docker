json.extract! package, :name, :last_synced_at, :versions_count, :latest_release_published_at, :latest_release_number, :created_at, :updated_at, :has_sbom, :dependencies_count, :description, :downloads, :repository_url
json.url api_v1_package_url(package, format: :json)
json.versions_url api_v1_package_versions_url(package_id: package.name)