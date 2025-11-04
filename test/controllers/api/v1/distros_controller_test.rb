require "test_helper"

class Api::V1::DistrosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @distro1 = Distro.create!(
      pretty_name: "Ubuntu 22.04.1 LTS",
      name: "Ubuntu",
      id_field: "ubuntu",
      version_id: "22.04",
      version_codename: "jammy",
      home_url: "https://www.ubuntu.com/",
      versions_count: 100,
      created_at: 5.days.ago,
      updated_at: 2.days.ago
    )

    @distro2 = Distro.create!(
      pretty_name: "Debian GNU/Linux 12 (bookworm)",
      name: "Debian GNU/Linux",
      id_field: "debian",
      version_id: "12",
      version_codename: "bookworm",
      versions_count: 50,
      created_at: 10.days.ago,
      updated_at: 6.days.ago
    )

    @distro3 = Distro.create!(
      pretty_name: "Alpine Linux v3.17",
      name: "Alpine Linux",
      id_field: "alpine",
      version_id: "3.17",
      versions_count: 200,
      created_at: 20.days.ago
    )
  end

  context "GET #index" do
    should "return successful JSON response" do
      get api_v1_distros_path, as: :json

      assert_response :success
      assert_match /application\/json/, response.content_type
    end

    should "return all distros" do
      get api_v1_distros_path, as: :json

      json = JSON.parse(response.body)
      pretty_names = json.map { |d| d['pretty_name'] }

      assert_includes pretty_names, 'Ubuntu 22.04.1 LTS'
      assert_includes pretty_names, 'Debian GNU/Linux 12 (bookworm)'
      assert_includes pretty_names, 'Alpine Linux v3.17'
    end

    should "include distro attributes in response" do
      get api_v1_distros_path, as: :json

      json = JSON.parse(response.body)
      ubuntu_distro = json.find { |d| d['id_field'] == 'ubuntu' }

      assert_equal 'Ubuntu 22.04.1 LTS', ubuntu_distro['pretty_name']
      assert_equal 'Ubuntu', ubuntu_distro['name']
      assert_equal 'ubuntu', ubuntu_distro['id_field']
      assert_equal '22.04', ubuntu_distro['version_id']
      assert_equal 'jammy', ubuntu_distro['version_codename']
      assert_equal 100, ubuntu_distro['versions_count']
      assert_equal 'https://www.ubuntu.com/', ubuntu_distro['home_url']
      assert_not_nil ubuntu_distro['slug']
    end

    should "search distros by pretty_name" do
      get api_v1_distros_path(query: 'ubuntu'), as: :json

      json = JSON.parse(response.body)
      assert_equal 1, json.length
      assert_equal 'Ubuntu 22.04.1 LTS', json[0]['pretty_name']
    end

    should "search distros by name" do
      get api_v1_distros_path(query: 'debian'), as: :json

      json = JSON.parse(response.body)
      assert_equal 1, json.length
      assert_equal 'Debian GNU/Linux 12 (bookworm)', json[0]['pretty_name']
    end

    should "search distros by id_field" do
      get api_v1_distros_path(query: 'alpine'), as: :json

      json = JSON.parse(response.body)
      assert_equal 1, json.length
      assert_equal 'Alpine Linux v3.17', json[0]['pretty_name']
    end

    should "support sorting by pretty_name" do
      get api_v1_distros_path(sort: 'pretty_name', order: 'asc'), as: :json

      json = JSON.parse(response.body)
      names = json.map { |d| d['pretty_name'] }
      assert_equal names.sort, names
    end

    should "support sorting by versions_count descending" do
      get api_v1_distros_path(sort: 'versions_count', order: 'desc'), as: :json

      json = JSON.parse(response.body)
      assert_equal 'Alpine Linux v3.17', json[0]['pretty_name'] # 200
      assert_equal 'Ubuntu 22.04.1 LTS', json[1]['pretty_name'] # 100
      assert_equal 'Debian GNU/Linux 12 (bookworm)', json[2]['pretty_name'] # 50
    end

    should "set proper cache headers" do
      get api_v1_distros_path, as: :json

      assert_response :success
      assert_not_nil response.headers['ETag']
      assert_not_nil response.headers['Last-Modified']
    end

    should "return 304 when not modified" do
      get api_v1_distros_path, as: :json
      etag = response.headers['ETag']

      get api_v1_distros_path,
          headers: { 'HTTP_IF_NONE_MATCH' => etag },
          as: :json

      assert_response :not_modified
    end

    should "include URLs in response" do
      get api_v1_distros_path, as: :json

      json = JSON.parse(response.body)
      ubuntu_distro = json.find { |d| d['id_field'] == 'ubuntu' }

      assert_not_nil ubuntu_distro['url']
      assert_not_nil ubuntu_distro['html_url']
      assert_match /api\/v1\/distros/, ubuntu_distro['url']
    end
  end

  context "GET #show" do
    should "return successful JSON response" do
      get api_v1_distro_path(@distro1.slug), as: :json

      assert_response :success
      assert_match /application\/json/, response.content_type
    end

    should "return distro details" do
      get api_v1_distro_path(@distro1.slug), as: :json

      json = JSON.parse(response.body)
      assert_equal 'Ubuntu 22.04.1 LTS', json['pretty_name']
      assert_equal 'Ubuntu', json['name']
      assert_equal 'ubuntu', json['id_field']
      assert_equal '22.04', json['version_id']
      assert_equal 'jammy', json['version_codename']
      assert_equal 100, json['versions_count']
    end

    should "include all distro fields" do
      get api_v1_distro_path(@distro1.slug), as: :json

      json = JSON.parse(response.body)
      assert_not_nil json['slug']
      assert_not_nil json['created_at']
      assert_not_nil json['updated_at']
      assert_not_nil json['url']
      assert_not_nil json['html_url']
    end

    should "set proper cache headers" do
      get api_v1_distro_path(@distro1.slug), as: :json

      assert_response :success
      assert_not_nil response.headers['ETag']
      assert_not_nil response.headers['Last-Modified']
    end

    should "return 304 when not modified" do
      get api_v1_distro_path(@distro1.slug), as: :json
      etag = response.headers['ETag']

      get api_v1_distro_path(@distro1.slug),
          headers: { 'HTTP_IF_NONE_MATCH' => etag },
          as: :json

      assert_response :not_modified
    end

    should "raise 404 for non-existent distro" do
      get api_v1_distro_path('non-existent'), as: :json
      assert_response :not_found
    end

    should "handle distro slugs with multiple hyphens" do
      get api_v1_distro_path(@distro2.slug), as: :json

      assert_response :success
      json = JSON.parse(response.body)
      assert_equal 'Debian GNU/Linux 12 (bookworm)', json['pretty_name']
    end
  end
end
