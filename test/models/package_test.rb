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

  test "sync_all_versions updates existing versions" do
    package = create(:package, name: "test/package")
    existing_version = create(:version, package: package, number: '1.0.0', published_at: 1.year.ago)

    # Mock API response with updated published_at
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

    # Check existing version was updated
    existing_version.reload
    assert_equal Time.parse('2024-01-01T00:00:00Z'), existing_version.published_at

    # Check new version was created
    assert package.versions.find_by(number: '2.0.0').present?
  end

  test "sync_all_versions updates versions_count" do
    package = create(:package, name: "test/package", versions_count: 0)

    versions_response = [
      { 'number' => '1.0.0', 'published_at' => '2024-01-01T00:00:00Z' },
      { 'number' => '2.0.0', 'published_at' => '2024-02-01T00:00:00Z' },
      { 'number' => '3.0.0', 'published_at' => '2024-03-01T00:00:00Z' }
    ].to_json

    stub_request(:get, "https://packages.ecosyste.ms/api/v1/registries/hub.docker.com/packages/test/package/versions?page=1&per_page=100")
      .to_return(status: 200, body: versions_response)

    stub_request(:get, "https://packages.ecosyste.ms/api/v1/registries/hub.docker.com/packages/test/package/versions?page=2&per_page=100")
      .to_return(status: 200, body: [].to_json)

    package.sync_all_versions

    package.reload
    assert_equal 3, package.versions_count
  end

  test "sync_all_versions handles multiple pages" do
    package = create(:package, name: "test/package")

    # First page
    page1_response = (1..100).map do |i|
      { 'number' => "#{i}.0.0", 'published_at' => '2024-01-01T00:00:00Z' }
    end.to_json

    # Second page
    page2_response = (101..150).map do |i|
      { 'number' => "#{i}.0.0", 'published_at' => '2024-01-01T00:00:00Z' }
    end.to_json

    stub_request(:get, "https://packages.ecosyste.ms/api/v1/registries/hub.docker.com/packages/test/package/versions?page=1&per_page=100")
      .to_return(status: 200, body: page1_response)

    stub_request(:get, "https://packages.ecosyste.ms/api/v1/registries/hub.docker.com/packages/test/package/versions?page=2&per_page=100")
      .to_return(status: 200, body: page2_response)

    stub_request(:get, "https://packages.ecosyste.ms/api/v1/registries/hub.docker.com/packages/test/package/versions?page=3&per_page=100")
      .to_return(status: 200, body: [].to_json)

    package.sync_all_versions

    assert_equal 150, package.versions.count
    assert_equal 150, package.reload.versions_count
  end

  test "sync_popular walks by updated_at cursor and advances it" do
    REDIS.stubs(:get).with('sync_popular_cursor').returns(nil)
    Package.any_instance.stubs(:sync)

    stub_request(:get, "https://packages.ecosyste.ms/api/v1/registries/hub.docker.com/packages?sort=updated_at&order=asc&updated_after=1970-01-01T00%3A00%3A00Z&per_page=100")
      .to_return(status: 200, body: [
        { name: "library/alpine", downloads: 1000, updated_at: "2026-11-01T00:00:00Z" },
        { name: "library/removed", downloads: 500, status: "removed", updated_at: "2026-11-02T00:00:00Z" },
        { name: "library/zero", downloads: 0, updated_at: "2026-11-03T00:00:00Z" },
        { name: "library/busybox", downloads: 2000, updated_at: "2026-11-04T00:00:00Z" },
      ].to_json)

    REDIS.expects(:set).with('sync_popular_cursor', '2026-11-04T00:00:00Z')

    Package.sync_popular

    assert Package.exists?(name: "library/alpine")
    assert Package.exists?(name: "library/busybox")
    refute Package.exists?(name: "library/removed")
    refute Package.exists?(name: "library/zero")
  end

  test "sync_popular resumes from stored cursor and does not advance on empty page" do
    REDIS.stubs(:get).with('sync_popular_cursor').returns('2026-11-04T00:00:00Z')
    REDIS.expects(:set).never

    stub_request(:get, "https://packages.ecosyste.ms/api/v1/registries/hub.docker.com/packages?sort=updated_at&order=asc&updated_after=2026-11-04T00%3A00%3A00Z&per_page=100")
      .to_return(status: 200, body: [].to_json)

    Package.sync_popular
  end

  test "sync_popular bumps the cursor when the response does not advance it" do
    REDIS.stubs(:get).with('sync_popular_cursor').returns('2026-11-01T00:07:11.830Z')
    Package.any_instance.stubs(:sync)

    stub_request(:get, "https://packages.ecosyste.ms/api/v1/registries/hub.docker.com/packages?sort=updated_at&order=asc&updated_after=2026-11-01T00%3A07%3A11.830Z&per_page=100")
      .to_return(status: 200, body: [{ name: "library/stuck", downloads: 1, updated_at: "2026-11-01T00:07:11.830Z" }].to_json)

    REDIS.expects(:set).with('sync_popular_cursor', '2026-11-01T00:07:11.831Z')

    Package.sync_popular
  end
end
