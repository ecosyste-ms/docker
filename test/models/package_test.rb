require "test_helper"

class PackageTest < ActiveSupport::TestCase
  test "created_after scope returns packages created after given time" do
    cutoff_time = Time.current

    old_package = Package.create!(name: "old_package")
    old_package.update_columns(created_at: cutoff_time - 2.days)

    new_package = Package.create!(name: "new_package")
    new_package.update_columns(created_at: cutoff_time + 1.hour)

    results = Package.created_after(cutoff_time)

    assert_includes results, new_package
    assert_not_includes results, old_package
  end

  test "updated_after scope returns packages updated after given time" do
    cutoff_time = Time.current

    old_package = Package.create!(name: "old_updated_package")
    old_package.update_columns(updated_at: cutoff_time - 2.days)

    new_package = Package.create!(name: "new_updated_package")
    new_package.update_columns(updated_at: cutoff_time + 1.hour)

    results = Package.updated_after(cutoff_time)

    assert_includes results, new_package
    assert_not_includes results, old_package
  end

  test "scopes can be chained" do
    cutoff_time = Time.current

    old_package = Package.create!(name: "old_package", status: "deprecated")
    old_package.update_columns(created_at: cutoff_time - 3.days, updated_at: cutoff_time - 3.days)

    active_recent = Package.create!(name: "active_recent", status: nil)
    active_recent.update_columns(created_at: cutoff_time + 1.hour, updated_at: cutoff_time + 1.hour)

    results = Package.active.created_after(cutoff_time)

    assert_includes results, active_recent
    assert_equal 1, results.count
  end

  test "sync_all_versions creates versions from API response" do
    package = Package.create!(name: "test/package")

    # Mock API response
    versions_response = [
      { 'number' => '1.0.0', 'published_at' => '2024-01-01T00:00:00Z' },
      { 'number' => '2.0.0', 'published_at' => '2024-02-01T00:00:00Z' }
    ].to_json

    stub_request(:get, "https://packages.ecosyste.ms/api/v1/registries/hub.docker.com/packages/test/package/versions?page=1&per_page=100")
      .to_return(status: 200, body: versions_response)

    stub_request(:get, "https://packages.ecosyste.ms/api/v1/registries/hub.docker.com/packages/test/package/versions?page=2&per_page=100")
      .to_return(status: 200, body: [].to_json)

    package.sync_all_versions

    assert_equal 2, package.versions.count
    assert package.versions.find_by(number: '1.0.0').present?
    assert package.versions.find_by(number: '2.0.0').present?
  end

  test "sync with all_versions parameter syncs all versions" do
    package = Package.create!(name: "test/package")

    # Mock package API response
    package_response = {
      'description' => 'Test package',
      'downloads' => 100,
      'latest_release_number' => '2.0.0'
    }.to_json

    stub_request(:get, "https://packages.ecosyste.ms/api/v1/registries/hub.docker.com/packages/test/package")
      .to_return(status: 200, body: package_response)

    # Mock versions API response
    versions_response = [
      { 'number' => '1.0.0', 'published_at' => '2024-01-01T00:00:00Z' }
    ].to_json

    stub_request(:get, "https://packages.ecosyste.ms/api/v1/registries/hub.docker.com/packages/test/package/versions?page=1&per_page=100")
      .to_return(status: 200, body: versions_response)

    stub_request(:get, "https://packages.ecosyste.ms/api/v1/registries/hub.docker.com/packages/test/package/versions?page=2&per_page=100")
      .to_return(status: 200, body: [].to_json)

    package.sync(all_versions: true)

    assert_equal 1, package.versions.count
  end
end
