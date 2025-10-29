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
end
