json.extract! @package_usage, :ecosystem, :name, :dependents_count, :downloads_count
json.dependencies_url api_v1_package_usage_dependencies_url(@package_usage.ecosystem, @package_usage.name)