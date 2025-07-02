require "test_helper"

class Api::V1::VersionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @package = Package.create!(name: 'redis')
    @version1 = Version.create!(
      package: @package,
      number: '7.0.5',
      published_at: 3.days.ago,
      created_at: 5.days.ago,
      updated_at: 2.days.ago
    )
    @version2 = Version.create!(
      package: @package,
      number: '7.0.4',
      published_at: 7.days.ago,
      created_at: 10.days.ago,
      updated_at: 6.days.ago
    )
    @version3 = Version.create!(
      package: @package,
      number: '7.0.3',
      published_at: 14.days.ago,
      created_at: 20.days.ago,
      updated_at: 12.days.ago
    )
  end

  context "GET #index" do
    should "return successful JSON response" do
      get api_v1_package_versions_path(@package.name), as: :json
      
      assert_response :success
      assert_equal 'application/json', response.content_type
    end
    
    should "return versions for package" do
      get api_v1_package_versions_path(@package.name), as: :json
      
      json = JSON.parse(response.body)
      assert_equal 3, json.length
      version_numbers = json.map { |v| v['number'] }
      assert_includes version_numbers, '7.0.5'
      assert_includes version_numbers, '7.0.4'
      assert_includes version_numbers, '7.0.3'
    end
    
    should "handle case-insensitive package names" do
      get api_v1_package_versions_path('REDIS'), as: :json
      
      assert_response :success
      json = JSON.parse(response.body)
      assert_equal 3, json.length
    end
    
    should "set proper cache headers" do
      get api_v1_package_versions_path(@package.name), as: :json
      
      assert_response :success
      assert_not_nil response.headers['ETag']
      assert_not_nil response.headers['Last-Modified']
    end
    
    should "return 304 when not modified" do
      get api_v1_package_versions_path(@package.name), as: :json
      etag = response.headers['ETag']
      
      get api_v1_package_versions_path(@package.name), 
          headers: { 'HTTP_IF_NONE_MATCH' => etag },
          as: :json
      
      assert_response :not_modified
    end
    
    context "sorting and ordering" do
      should "sort by published_at desc by default" do
        get api_v1_package_versions_path(@package.name), as: :json
        
        json = JSON.parse(response.body)
        assert_equal '7.0.5', json[0]['number'] # Most recent
        assert_equal '7.0.4', json[1]['number']
        assert_equal '7.0.3', json[2]['number'] # Oldest
      end
      
      should "sort by created_at asc when specified" do
        get api_v1_package_versions_path(@package.name, sort: 'created_at', order: 'asc'), as: :json
        
        json = JSON.parse(response.body)
        assert_equal '7.0.3', json[0]['number'] # Oldest created
        assert_equal '7.0.4', json[1]['number']
        assert_equal '7.0.5', json[2]['number'] # Newest created
      end
      
      should "support multiple sort fields" do
        get api_v1_package_versions_path(@package.name, sort: 'published_at,created_at', order: 'desc,asc'), as: :json
        
        assert_response :success
      end
    end
    
    context "filtering" do
      should "filter by created_after" do
        get api_v1_package_versions_path(@package.name, created_after: 8.days.ago.iso8601), as: :json
        
        json = JSON.parse(response.body)
        assert_equal 1, json.length
        assert_equal '7.0.5', json[0]['number']
      end
      
      should "filter by published_after" do
        get api_v1_package_versions_path(@package.name, published_after: 10.days.ago.iso8601), as: :json
        
        json = JSON.parse(response.body)
        assert_equal 2, json.length
        version_numbers = json.map { |v| v['number'] }
        assert_includes version_numbers, '7.0.5'
        assert_includes version_numbers, '7.0.4'
      end
      
      should "filter by updated_after" do
        get api_v1_package_versions_path(@package.name, updated_after: 7.days.ago.iso8601), as: :json
        
        json = JSON.parse(response.body)
        assert_equal 2, json.length
        version_numbers = json.map { |v| v['number'] }
        assert_includes version_numbers, '7.0.5'
        assert_includes version_numbers, '7.0.4'
      end
    end
    
    should "include dependencies in response" do
      dependency = Dependency.create!(
        version: @version1,
        package: @package,
        ecosystem: 'npm',
        package_name: 'express',
        requirements: '4.18.2',
        purl: 'pkg:npm/express@4.18.2'
      )
      
      get api_v1_package_versions_path(@package.name), as: :json
      
      json = JSON.parse(response.body)
      version_with_deps = json.find { |v| v['number'] == '7.0.5' }
      assert_equal 1, version_with_deps['dependencies'].length
      assert_equal 'express', version_with_deps['dependencies'][0]['package_name']
    end
    
    should "raise 404 for non-existent package" do
      assert_raises(ActiveRecord::RecordNotFound) do
        get api_v1_package_versions_path('non-existent'), as: :json
      end
    end
  end

  context "GET #show" do
    should "return successful JSON response" do
      get api_v1_package_version_path(@package.name, @version1.number), as: :json
      
      assert_response :success
      assert_equal 'application/json', response.content_type
    end
    
    should "return version details" do
      get api_v1_package_version_path(@package.name, @version1.number), as: :json
      
      json = JSON.parse(response.body)
      assert_equal '7.0.5', json['number']
      assert_equal @package.name, json['package']['name']
    end
    
    should "handle case-insensitive package names" do
      get api_v1_package_version_path('REDIS', @version1.number), as: :json
      
      assert_response :success
      json = JSON.parse(response.body)
      assert_equal '7.0.5', json['number']
    end
    
    should "set proper cache headers" do
      get api_v1_package_version_path(@package.name, @version1.number), as: :json
      
      assert_response :success
      assert_not_nil response.headers['ETag']
      assert_not_nil response.headers['Last-Modified']
    end
    
    should "include dependencies in response" do
      dependency = Dependency.create!(
        version: @version1,
        package: @package,
        ecosystem: 'npm',
        package_name: 'express',
        requirements: '4.18.2',
        purl: 'pkg:npm/express@4.18.2'
      )
      
      get api_v1_package_version_path(@package.name, @version1.number), as: :json
      
      json = JSON.parse(response.body)
      assert_equal 1, json['dependencies'].length
      assert_equal 'express', json['dependencies'][0]['package_name']
    end
    
    should "raise 404 for non-existent package" do
      assert_raises(ActiveRecord::RecordNotFound) do
        get api_v1_package_version_path('non-existent', '1.0.0'), as: :json
      end
    end
    
    should "raise 404 for non-existent version" do
      assert_raises(ActiveRecord::RecordNotFound) do
        get api_v1_package_version_path(@package.name, 'non-existent'), as: :json
      end
    end
    
    context "with SBOM data" do
      setup do
        @sbom_data = {
          'distro' => { 'prettyName' => 'Alpine Linux v3.17' },
          'descriptor' => { 'version' => 'v0.70.0' },
          'artifacts' => [
            { 'purl' => 'pkg:npm/express@4.18.2' }
          ]
        }
      end
      
      should "include SBOM information in response" do
        @version1.update!(
          sbom: @sbom_data,
          distro_name: 'Alpine Linux v3.17',
          syft_version: 'v0.70.0',
          artifacts_count: 1
        )
        
        get api_v1_package_version_path(@package.name, @version1.number), as: :json
        
        json = JSON.parse(response.body)
        assert json['has_sbom']
        assert_equal 'Alpine Linux v3.17', json['distro_name']
        assert_equal 'v0.70.0', json['syft_version']
        assert_equal 1, json['artifacts_count']
      end
    end
  end
end