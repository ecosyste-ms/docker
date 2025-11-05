require "test_helper"

class EcosystemTest < ActiveSupport::TestCase
  context "validations" do
    should "require name" do
      ecosystem = build(:ecosystem, name: nil)
      assert_not ecosystem.valid?
      assert_includes ecosystem.errors[:name], "can't be blank"
    end

    should "require unique name" do
      create(:ecosystem, :npm)
      duplicate = build(:ecosystem, :npm)
      assert_not duplicate.valid?
      assert_includes duplicate.errors[:name], "has already been taken"
    end
  end

  context ".refresh_stats" do
    setup do
      PackageUsage.destroy_all
      Ecosystem.destroy_all

      create(:package_usage, :npm, name: 'express', dependents_count: 1000, downloads_count: 50000)
      create(:package_usage, :npm, name: 'lodash', dependents_count: 2000, downloads_count: 100000)
      create(:package_usage, :maven, name: 'spring-boot', dependents_count: 500, downloads_count: 25000)
      create(:package_usage, :maven, name: 'junit', dependents_count: 800, downloads_count: 40000)
      create(:package_usage, :gem, name: 'rails', dependents_count: 300, downloads_count: 15000)
    end

    should "create ecosystem records from package usage data" do
      Ecosystem.refresh_stats

      assert_equal 3, Ecosystem.count

      npm = Ecosystem.find_by(name: 'npm')
      assert_not_nil npm
      assert_equal 2, npm.packages_count
      assert_equal 150000, npm.total_downloads

      maven = Ecosystem.find_by(name: 'maven')
      assert_not_nil maven
      assert_equal 2, maven.packages_count
      assert_equal 65000, maven.total_downloads

      gem = Ecosystem.find_by(name: 'gem')
      assert_not_nil gem
      assert_equal 1, gem.packages_count
      assert_equal 15000, gem.total_downloads
    end

    should "update existing ecosystem records" do
      existing = create(:ecosystem, :npm, packages_count: 0, total_downloads: 0)

      Ecosystem.refresh_stats

      existing.reload
      assert_equal 2, existing.packages_count
      assert_equal 150000, existing.total_downloads
    end

    should "handle null downloads_count" do
      create(:package_usage, :pypi, name: 'django', dependents_count: 100, downloads_count: nil)

      Ecosystem.refresh_stats

      pypi = Ecosystem.find_by(name: 'pypi')
      assert_not_nil pypi
      assert_equal 1, pypi.packages_count
      assert_equal 0, pypi.total_downloads
    end
  end
end
