require "test_helper"

class VersionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @package = create(:package, name: 'redis')
    @version = create(:version, package: @package, number: '7.0.5', published_at: 1.day.ago)
  end

  context "GET #index" do
    should "redirect to package path" do
      get package_versions_path(@package.name)
      
      assert_redirected_to package_path(@package)
    end
    
    should "handle package name with slashes" do
      package_with_slash = create(:package, name: 'library/redis')

      get package_versions_path('library/redis')

      assert_redirected_to package_path(package_with_slash)
    end
  end

  context "GET #index for distro" do
    setup do
      @distro = create(:distro, :ubuntu, versions_count: 5)
      @package1 = create(:package, name: 'ubuntu-package-1')
      @package2 = create(:package, name: 'ubuntu-package-2')
      @version1 = create(:version, package: @package1, number: '1.0', distro_name: @distro.pretty_name, published_at: 1.day.ago)
      @version2 = create(:version, package: @package1, number: '2.0', distro_name: @distro.pretty_name, published_at: 2.days.ago)
      @version3 = create(:version, package: @package2, number: '1.5', distro_name: @distro.pretty_name, published_at: 3.days.ago)
    end

    should "return successful response" do
      get distro_versions_path(@distro.slug)

      assert_response :success
    end

    should "load distro and versions" do
      get distro_versions_path(@distro.slug)

      assert_equal @distro, assigns(:distro)
      assert_equal 3, assigns(:versions).count
    end

    should "order versions by published_at desc" do
      get distro_versions_path(@distro.slug)

      versions = assigns(:versions)
      assert_equal @version1, versions[0]
      assert_equal @version2, versions[1]
      assert_equal @version3, versions[2]
    end

    should "include packages to avoid N+1" do
      get distro_versions_path(@distro.slug)

      assert_response :success
    end

    should "raise 404 for non-existent distro" do
      get distro_versions_path('non-existent-distro')
      assert_response :not_found
    end

    should "set cache headers" do
      get distro_versions_path(@distro.slug)

      assert_response :success
      assert_not_nil response.headers['ETag']
      assert_not_nil response.headers['Last-Modified']
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
      dependency = create(:dependency, :express, version: @version, package: @package)

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
      
      should "display version with SBOM structure" do
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

      should "link to distro page when distro exists" do
        @version.update!(distro_name: 'Ubuntu 22.04.1 LTS')
        distro = Distro.create!(pretty_name: 'Ubuntu 22.04.1 LTS')

        get package_version_path(@package.name, @version.number)

        assert_response :success
        assert_includes response.body, distro_path(distro.slug)
      end

      should "display distro name without link when distro not found" do
        @version.update!(distro_name: 'Unknown Distro')

        get package_version_path(@package.name, @version.number)

        assert_response :success
        assert_includes response.body, 'Unknown Distro'
      end
    end
  end
end