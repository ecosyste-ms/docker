require "test_helper"

class PackageUsagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Ecosystem.destroy_all

    @npm = create(:ecosystem, :npm)
    @maven = create(:ecosystem, :maven)
    @gem = create(:ecosystem, :gem)
  end

  context "GET #index" do
    should "return successful response" do
      get package_usages_path

      assert_response :success
    end

    should "load ecosystems from cache table" do
      get package_usages_path

      assert_response :success
      ecosystems = assigns(:ecosystems)
      assert_equal 3, ecosystems.length
    end

    should "order ecosystems by packages_count descending" do
      get package_usages_path

      ecosystems = assigns(:ecosystems)
      assert_equal 'npm', ecosystems[0][:ecosystem]
      assert_equal 'maven', ecosystems[1][:ecosystem]
      assert_equal 'gem', ecosystems[2][:ecosystem]
    end

    should "include packages count and total downloads" do
      get package_usages_path

      ecosystems = assigns(:ecosystems)
      npm_data = ecosystems.find { |e| e[:ecosystem] == 'npm' }

      assert_equal 1000, npm_data[:count]
      assert_equal 5000000, npm_data[:downloads]
    end

    should "set cache headers" do
      get package_usages_path

      assert_response :success
      assert_includes response.headers['Cache-Control'], 'max-age=86400'
      assert_includes response.headers['Cache-Control'], 'public'
    end
  end
end
