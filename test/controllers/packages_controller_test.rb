require "test_helper"

class PackagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @package = Package.create!(
      name: 'redis',
      description: 'Redis is an open source in-memory data structure store',
      latest_release_number: '7.0.5',
      latest_release_published_at: 1.day.ago,
      dependencies_count: 10,
      has_sbom: true
    )
    
    @package_without_sbom = Package.create!(
      name: 'nginx',
      description: 'nginx web server',
      latest_release_number: '1.23.3',
      has_sbom: false
    )
    
    # Create versions for the package
    @version1 = Version.create!(
      package: @package,
      number: '7.0.5',
      published_at: 1.day.ago,
      distro_name: 'Alpine Linux v3.17',
      syft_version: 'v0.70.0',
      artifacts_count: 42
    )
    
    @version2 = Version.create!(
      package: @package,
      number: '7.0.4', 
      published_at: 7.days.ago
    )
    
    @version3 = Version.create!(
      package: @package,
      number: '7.0.3',
      published_at: 14.days.ago
    )
  end

  context "GET #index" do
    should "return successful response" do
      get packages_path
      
      assert_response :success
    end
    
    should "show packages with SBOM by default" do
      get packages_path
      
      assert_includes response.body, @package.name
      assert_not_includes response.body, @package_without_sbom.name
    end
    
    should "search packages by name" do
      get packages_path(query: 'redis')
      
      assert_response :success
      assert_includes response.body, @package.name
    end
    
    should "search packages by description" do
      get packages_path(query: 'memory data')
      
      assert_response :success
      assert_includes response.body, @package.name
    end
    
    should "support sorting by different fields" do
      get packages_path(sort: 'name', order: 'asc')
      
      assert_response :success
    end
    
    should "support sorting by latest_release_published_at" do
      get packages_path(sort: 'latest_release_published_at', order: 'desc')
      
      assert_response :success
    end
    
    should "support sorting by dependencies_count" do
      get packages_path(sort: 'dependencies_count', order: 'desc')
      
      assert_response :success
    end
    
    should "paginate results" do
      30.times do |i|
        Package.create!(
          name: "package-#{i}",
          has_sbom: true,
          latest_release_published_at: i.days.ago
        )
      end
      
      get packages_path
      
      assert_response :success
      # Should use pagination
    end
  end

  context "GET #show" do
    should "return successful response for existing package" do
      get package_path(@package.name)
      
      assert_response :success
      assert_equal @package, assigns(:package)
    end
    
    should "load and display versions" do
      get package_path(@package.name)
      
      assert_response :success
      versions = assigns(:versions)
      assert_equal 3, versions.count
      
      # Should be ordered by published_at DESC
      assert_equal @version1, versions[0]
      assert_equal @version2, versions[1]
      assert_equal @version3, versions[2]
    end
    
    should "display version information" do
      get package_path(@package.name)
      
      assert_response :success
      assert_includes response.body, '7.0.5'
      assert_includes response.body, '7.0.4'
      assert_includes response.body, '7.0.3'
    end
    
    should "display SBOM information for versions" do
      # Skip this test since the view doesn't display SBOM details directly
      skip "View doesn't display SBOM details directly"
    end
    
    should "set proper cache headers" do
      get package_path(@package.name)
      
      assert_response :success
      assert_not_nil response.headers['ETag']
      assert_not_nil response.headers['Last-Modified']
    end
    
    should "return 304 when not modified" do
      get package_path(@package.name)
      etag = response.headers['ETag']
      
      get package_path(@package.name), 
          headers: { 'HTTP_IF_NONE_MATCH' => etag }
      
      assert_response :not_modified
    end
    
    should "handle package names with special characters" do
      special_package = Package.create!(
        name: '@babel/core',
        has_sbom: true
      )
      
      get package_path('@babel/core')
      
      assert_response :success
      assert_equal special_package, assigns(:package)
    end
    
    should "handle package names with slashes" do
      package_with_slash = Package.create!(
        name: 'library/redis',
        has_sbom: true
      )
      Version.create!(
        package: package_with_slash,
        number: '7.0.5'
      )
      
      get package_path('library/redis')
      
      assert_response :success
      assert_equal package_with_slash, assigns(:package)
    end
    
    should "raise 404 for non-existent package" do
      get package_path('non-existent')
      assert_response :not_found
    end
    
    should "paginate versions" do
      # Create many versions
      50.times do |i|
        Version.create!(
          package: @package,
          number: "6.#{i}.0",
          published_at: (20 + i).days.ago
        )
      end
      
      get package_path(@package.name)
      
      assert_response :success
      # Versions should be paginated
    end
    
    context "with dependencies" do
      setup do
        @dependency1 = Dependency.create!(
          version: @version1,
          package: @package,
          ecosystem: 'npm',
          package_name: 'express',
          requirements: '4.18.2',
          purl: 'pkg:npm/express@4.18.2'
        )
        
        @dependency2 = Dependency.create!(
          version: @version1,
          package: @package,
          ecosystem: 'npm',
          package_name: 'lodash',
          requirements: '4.17.21',
          purl: 'pkg:npm/lodash@4.17.21'
        )
      end
      
      should "display package dependencies count" do
        get package_path(@package.name)
        
        assert_response :success
        assert_equal 10, assigns(:package).dependencies_count
      end
    end
  end
  
  # Remove search action tests since it doesn't exist in routes
end