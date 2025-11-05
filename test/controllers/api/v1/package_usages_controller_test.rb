require "test_helper"

class Api::V1::PackageUsagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Ecosystem.destroy_all

    @npm = create(:ecosystem, :npm)
    @maven = create(:ecosystem, :maven)
    @gem = create(:ecosystem, :gem)
  end

  context "GET #index" do
    should "return successful json response" do
      get api_v1_package_usages_path, as: :json

      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
    end

    should "return ecosystems from cache table" do
      get api_v1_package_usages_path, as: :json

      json = JSON.parse(response.body)
      assert_equal 3, json.length
    end

    should "order ecosystems by packages_count descending" do
      get api_v1_package_usages_path, as: :json

      json = JSON.parse(response.body)
      assert_equal 'npm', json[0]['name']
      assert_equal 'maven', json[1]['name']
      assert_equal 'gem', json[2]['name']
    end

    should "include all ecosystem data" do
      get api_v1_package_usages_path, as: :json

      json = JSON.parse(response.body)
      npm_data = json.find { |e| e['name'] == 'npm' }

      assert_equal 1000, npm_data['packages_count']
      assert_equal 5000000, npm_data['total_downloads']
      assert_includes npm_data['ecosystem_url'], '/api/v1/usage/npm'
    end

    should "set cache headers" do
      get api_v1_package_usages_path, as: :json

      assert_response :success
      assert_includes response.headers['Cache-Control'], 'max-age=86400'
      assert_includes response.headers['Cache-Control'], 'public'
    end
  end
end
