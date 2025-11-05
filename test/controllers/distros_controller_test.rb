require "test_helper"

class DistrosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @distro1 = create(:distro, :ubuntu)
    @distro2 = create(:distro, :debian)
    @distro3 = create(:distro, :alpine)
  end

  context "GET #index" do
    should "return successful response" do
      get distros_path

      assert_response :success
    end

    should "display all distros" do
      get distros_path

      assert_response :success
      assert_includes response.body, @distro1.version_id
      assert_includes response.body, @distro2.version_id
      assert_includes response.body, @distro3.version_id
    end

    should "group distros by id_field" do
      @distro1b = create(:distro, :ubuntu_focal)

      get distros_path

      assert_response :success
      distro_groups = assigns(:distro_groups)
      assert_not_nil distro_groups
      assert_includes distro_groups.keys, "ubuntu"
      assert_equal 2, distro_groups["ubuntu"].count
      assert_includes distro_groups["ubuntu"], @distro1
      assert_includes distro_groups["ubuntu"], @distro1b
    end

    should "search distros by pretty_name" do
      get distros_path(query: 'ubuntu')

      assert_response :success
      distro_groups = assigns(:distro_groups)
      assert_includes distro_groups.keys, "ubuntu"
      assert_not_includes distro_groups.keys, "debian"
    end

    should "search distros by name" do
      get distros_path(query: 'debian')

      assert_response :success
      distro_groups = assigns(:distro_groups)
      assert_includes distro_groups.keys, "debian"
      assert_not_includes distro_groups.keys, "ubuntu"
    end

    should "search distros by id_field" do
      get distros_path(query: 'alpine')

      assert_response :success
      distro_groups = assigns(:distro_groups)
      assert_includes distro_groups.keys, "alpine"
      assert_not_includes distro_groups.keys, "ubuntu"
    end

    should "sort groups by total versions_count descending" do
      # Update versions_count to create different totals
      @distro1.update_column(:versions_count, 100)
      @distro2.update_column(:versions_count, 500)
      @distro3.update_column(:versions_count, 50)

      get distros_path

      assert_response :success
      distro_groups = assigns(:distro_groups)
      group_keys = distro_groups.keys

      # Debian should be first (500), then Ubuntu (100), then Alpine (50)
      assert_equal "debian", group_keys[0]
      assert_equal "ubuntu", group_keys[1]
      assert_equal "alpine", group_keys[2]
    end

    should "handle distros without id_field" do
      distro_no_id = Distro.create!(
        pretty_name: "Unknown Distro",
        name: "Unknown"
      )

      get distros_path

      assert_response :success
      distro_groups = assigns(:distro_groups)
      # Should be grouped by name when id_field is missing
      assert_includes distro_groups.keys, "unknown"
      assert_includes distro_groups["unknown"], distro_no_id
    end

    should "separate derivative distros from base distros" do
      # Pengwin is based on Debian but should be grouped separately
      pengwin = Distro.create!(
        pretty_name: "Pengwin",
        name: "Pengwin",
        id_field: "debian",
        version_id: "11",
        version_codename: "bullseye"
      )

      get distros_path

      assert_response :success
      distro_groups = assigns(:distro_groups)

      # Pengwin should be in its own group, not grouped with Debian
      assert_includes distro_groups.keys, "pengwin"
      assert_includes distro_groups["pengwin"], pengwin
      assert_not_includes distro_groups["debian"], pengwin
    end
  end

  context "GET #show" do
    should "return successful response for existing distro" do
      get distro_path(@distro1.slug)

      assert_response :success
      assert_equal @distro1, assigns(:distro)
    end

    should "display distro information" do
      get distro_path(@distro1.slug)

      assert_response :success
      assert_includes response.body, @distro1.pretty_name
      assert_includes response.body, @distro1.id_field
      assert_includes response.body, @distro1.version_id
      assert_includes response.body, @distro1.version_codename
    end

    should "display distro links" do
      get distro_path(@distro1.slug)

      assert_response :success
      assert_includes response.body, @distro1.home_url
      assert_includes response.body, @distro1.support_url
      assert_includes response.body, @distro1.bug_report_url
    end

    should "set proper cache headers" do
      get distro_path(@distro1.slug)

      assert_response :success
      assert_not_nil response.headers['ETag']
      assert_not_nil response.headers['Last-Modified']
    end

    should "return 304 when not modified" do
      get distro_path(@distro1.slug)
      etag = response.headers['ETag']

      get distro_path(@distro1.slug),
          headers: { 'HTTP_IF_NONE_MATCH' => etag }

      assert_response :not_modified
    end

    should "raise 404 for non-existent distro" do
      get distro_path('non-existent')
      assert_response :not_found
    end

    should "handle distro slugs with multiple hyphens" do
      get distro_path(@distro2.slug)

      assert_response :success
      assert_equal @distro2, assigns(:distro)
    end
  end
end
