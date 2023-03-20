json.array! @dependencies do |dependency|
  json.extract! dependency, :id, :package_name, :ecosystem, :requirements, :purl
  json.package do
    json.partial! 'api/v1/packages/package', package: dependency.package
  end
end