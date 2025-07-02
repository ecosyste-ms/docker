require "test_helper"

class VersionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @package = Package.create!(name: 'redis')
    @version = Version.create!(
      package: @package,
      number: '7.0.5',
      published_at: 1.day.ago
    )
  end

  context "GET #index" do
    should "redirect to package path" do
      get package_versions_path(@package.name)
      
      assert_redirected_to package_path(@package)
    end
    
    should "handle package name with slashes" do
      package_with_slash = Package.create!(name: 'library/redis')
      
      get package_versions_path('library/redis')
      
      assert_redirected_to package_path(package_with_slash)
    end
  end

  context "GET #show" do
    should "return successful response for existing version" do
      get package_version_path(@package.name, @version.number)
      
      assert_response :success
      assert_equal @package, assigns(:package)
      assert_equal @version, assigns(:version)
    end
    
    should "set proper cache headers" do
      get package_version_path(@package.name, @version.number)
      
      assert_response :success
      assert_not_nil response.headers['ETag']
      assert_not_nil response.headers['Last-Modified']
    end
    
    should "return 304 when not modified" do
      get package_version_path(@package.name, @version.number)
      etag = response.headers['ETag']
      
      get package_version_path(@package.name, @version.number), 
          headers: { 'HTTP_IF_NONE_MATCH' => etag }
      
      assert_response :not_modified
    end
    
    should "include dependencies in query" do
      dependency = Dependency.create!(
        version: @version,
        package: @package,
        ecosystem: 'npm',
        package_name: 'express',
        requirements: '4.18.2',
        purl: 'pkg:npm/express@4.18.2'
      )
      
      get package_version_path(@package.name, @version.number)
      
      assert_response :success
      # Check that dependencies are loaded to avoid N+1
      assert_includes assigns(:version).dependencies, dependency
    end
    
    should "return 404 for non-existent package" do
      get package_version_path('non-existent', '1.0.0')
      assert_response :not_found
    end
    
    should "return 404 for non-existent version" do
      get package_version_path(@package.name, 'non-existent')
      assert_response :not_found
    end
    
    should "handle package names with special characters" do
      special_package = Package.create!(name: '@babel/core')
      special_version = Version.create!(
        package: special_package,
        number: '7.20.0'
      )
      
      get package_version_path('@babel/core', '7.20.0')
      
      assert_response :success
      assert_equal special_package, assigns(:package)
      assert_equal special_version, assigns(:version)
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
      
      should "display version with old SBOM structure" do
        @version.update!(sbom: @sbom_data)
        
        get package_version_path(@package.name, @version.number)
        
        assert_response :success
        assert @version.has_sbom?
      end
      
      should "display version with new SBOM structure" do
        @version.create_sbom_record!(data: @sbom_data)
        @version.update!(
          distro_name: 'Alpine Linux v3.17',
          syft_version: 'v0.70.0',
          artifacts_count: 1
        )
        
        get package_version_path(@package.name, @version.number)
        
        assert_response :success
        assert @version.has_sbom?
      end
    end
  end
end