require "test_helper"
require "uri"

class OpenapiTest < ActionDispatch::IntegrationTest
  SPEC = YAML.load_file(Rails.root.join('openapi/api/v1/openapi.yaml'))

  setup do
    @exception_settings = Rails.application.env_config.slice('action_dispatch.show_detailed_exceptions', 'action_dispatch.show_exceptions')
    Rails.application.env_config.merge!('action_dispatch.show_detailed_exceptions' => false, 'action_dispatch.show_exceptions' => :all)
    @package = create(:package, name: 'library/redis', downloads: 100, repository_url: nil)
    @distro = create(:distro)
    @version = create(:version, package: @package, number: 'latest', distro_name: @distro.pretty_name)
    create(:version, package: @package, number: 'unscanned', published_at: nil, distro_name: nil)
    @usage = create(:package_usage, ecosystem: 'npm', name: '@example/core')
    create(:ecosystem, name: @usage.ecosystem)
    create(:dependency, package: @package, version: @version, ecosystem: @usage.ecosystem,
      package_name: @usage.name, requirements: '1.0.0', purl: 'pkg:npm/%40example/core@1.0.0')
  end

  teardown do
    Rails.application.env_config.merge!(@exception_settings)
  end

  test 'served OpenAPI document matches the checked-in document' do
    get '/docs/api/v1/openapi.yaml'

    assert_response :success
    assert_equal SPEC, YAML.safe_load(response.body)
  end

  test 'all API routes are documented' do
    actual = Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s
      next unless path.start_with?('/api/v1/')

      [route.verb.downcase, path.delete_prefix('/api/v1').delete_suffix('(.:format)').gsub(/:\w+/, '{}')]
    end
    documented = SPEC.fetch('paths').flat_map do |path, operations|
      operations.keys.map { |verb| [verb, path.gsub(/\{[^}]+\}/, '{}')] }
    end

    assert_equal actual.sort, documented.sort
  end

  test 'references resolve and operation IDs are unique' do
    assert_references(SPEC)
    ids = SPEC.fetch('paths').values.map { |item| item.fetch('get').fetch('operationId') }
    assert_equal ids.uniq, ids
    SPEC.fetch('components').fetch('schemas').each_value do |schema|
      assert_schema(schema['example'], schema) if schema.key?('example')
    end
  end

  SPEC.fetch('paths').each do |path, item|
    operation = item.fetch('get')

    test "GET #{path} matches its documented response" do
      parameters = operation.fetch('parameters').map { |parameter| resolve(parameter) }
      assert_equal path.scan(/\{([^}]+)\}/).flatten.sort,
        parameters.select { |parameter| parameter['in'] == 'path' }.map { |parameter| parameter.fetch('name') }.sort

      get request_path(path), as: :json

      assert_response :success
      assert_documented_response(operation, '200')
      assert_not_empty response.parsed_body if response.parsed_body.is_a?(Array)
    end

    if operation.fetch('responses').key?('304')
      test "GET #{path} supports its documented conditional response" do
        get request_path(path), as: :json
        etag = response.headers.fetch('ETag')

        get request_path(path), headers: { 'If-None-Match' => etag }, as: :json

        assert_response :not_modified
        assert_empty response.body
        refute resolve(operation['responses']['304']).key?('content')
      end
    end

    if operation.fetch('responses').key?('404')
      test "GET #{path} matches its documented not-found response" do
        get request_path(path, missing: true), as: :json

        assert_response :not_found
        assert_documented_response(operation, '404')
        assert_equal({ 'error' => 'not found' }, response.parsed_body)
      end
    end

    if operation.fetch('parameters').include?({ '$ref' => '#/components/parameters/PerPage' })
      test "GET #{path} uses the documented pagination limits" do
        params = operation['parameters'].map { |parameter| resolve(parameter) }.index_by { |parameter| parameter['name'] }
        page_size = params.fetch('per_page').fetch('schema')

        get request_path(path), as: :json
        assert_response :success
        assert_equal page_size.fetch('default'), response.headers.fetch('Page-Items').to_i
        assert_equal params.fetch('page').fetch('schema').fetch('default'), response.headers.fetch('Current-Page').to_i

        get request_path(path), params: { per_page: page_size.fetch('maximum') + 1 }, as: :json
        assert_response :success
        assert_equal page_size.fetch('maximum'), response.headers.fetch('Page-Items').to_i

        get request_path(path), params: { per_page: 1 }, as: :json
        assert_response :success
        assert_equal 1, response.parsed_body.length
        assert_equal '1', response.headers['Page-Items']
      end
    end
  end

  test 'nullable metadata matches the response schemas' do
    @package.update_columns(description: nil, latest_release_published_at: nil, latest_release_number: nil,
      downloads: nil, has_sbom: nil, dependencies_count: nil, versions_count: nil)
    @distro.update_columns(name: nil, id_field: nil, id_like: nil, version_id: nil, versions_count: nil)
    @usage.update_columns(dependents_count: nil, downloads_count: nil)
    Ecosystem.find_by!(name: @usage.ecosystem).update_columns(packages_count: nil, total_downloads: nil)

    %w[/packages/{packageName} /distros/{slug} /usage /usage/{ecosystem} /usage/{ecosystem}/{package}].each do |path|
      get request_path(path), as: :json

      assert_response :success
      assert_documented_response(SPEC['paths'].fetch(path).fetch('get'), '200')
    end
  end

  test 'usage pagination follows next links and returns the documented 404 on empty pages' do
    create(:package_usage, ecosystem: @usage.ecosystem)
    path = '/usage/{ecosystem}'
    operation = SPEC['paths'].fetch(path).fetch('get')

    get request_path(path), params: { per_page: 1 }, as: :json
    assert_response :success
    first_name = response.parsed_body.first.fetch('name')
    next_url = response.headers.fetch('Link').match(/<([^>]+)>; rel="next"/)[1]

    get next_url, as: :json
    assert_response :success
    refute_equal first_name, response.parsed_body.first.fetch('name')
    refute_includes response.headers.fetch('Link'), 'rel="next"'

    get request_path(path), params: { per_page: 1, page: 3 }, as: :json
    assert_response :not_found
    assert_documented_response(operation, '404')

    get request_path(path), params: { created_after: 1.day.from_now.iso8601 }, as: :json
    assert_response :not_found
    assert_documented_response(operation, '404')
  end

  test 'search and ecosystem sorting parameters are documented and work' do
    packages = SPEC['paths'].fetch('/packages').fetch('get')
    assert_includes packages['parameters'].map { |parameter| resolve(parameter)['name'] }, 'query'
    get '/api/v1/packages', params: { query: 'LIBRARY/REDIS' }, as: :json
    assert_response :success
    assert_equal [@package.name], response.parsed_body.map { |package| package['name'] }

    usage = SPEC['paths'].fetch('/usage').fetch('get')
    parameters = usage['parameters'].index_by { |parameter| parameter['name'] }
    assert_equal %w[name packages_count total_downloads], parameters.fetch('sort').dig('schema', 'enum')
    assert_equal %w[asc desc], parameters.fetch('order').dig('schema', 'enum')
    create(:ecosystem, name: 'gem', packages_count: 1)
    get '/api/v1/usage', params: { sort: 'name', order: 'asc' }, as: :json
    assert_response :success
    assert_equal %w[gem npm], response.parsed_body.map { |ecosystem| ecosystem['name'] }
  end

  def request_path(path, missing: false)
    values = { 'packageName' => @package.name, 'versionNumber' => @version.number,
      'slug' => @distro.slug, 'ecosystem' => @usage.ecosystem, 'package' => @usage.name }
    "/api/v1#{path.gsub(/\{([^}]+)\}/) { ERB::Util.url_encode(missing ? 'missing' : values.fetch(Regexp.last_match(1))) }}"
  end

  def resolve(object)
    return object unless object.key?('$ref')

    object.fetch('$ref').delete_prefix('#/').split('/').reduce(SPEC) { |node, key| node.fetch(key) }
  end

  def assert_references(value)
    case value
    when Hash
      assert_kind_of Hash, resolve(value) if value.key?('$ref')
      value.each_value { |child| assert_references(child) }
    when Array
      value.each { |child| assert_references(child) }
    end
  end

  def assert_documented_response(operation, status)
    assert_equal 'application/json', response.media_type
    documented = resolve(operation.fetch('responses').fetch(status))
    assert_schema(response.parsed_body, documented.fetch('content').fetch('application/json').fetch('schema'))
    documented.fetch('headers', {}).each_key { |name| assert response.headers.key?(name), "Missing header #{name}" }
  end

  def assert_schema(value, schema)
    schema = resolve(schema)
    if value.nil?
      assert schema['nullable'], "Unexpected null for #{schema.inspect}"
      return
    end

    case schema.fetch('type')
    when 'object'
      assert_kind_of Hash, value
      properties = schema.fetch('properties')
      assert_equal properties.keys.sort, value.keys.sort
      assert_equal properties.keys.sort, schema.fetch('required').sort
      value.each { |key, child| assert_schema(child, properties.fetch(key)) }
    when 'array'
      assert_kind_of Array, value
      value.each { |child| assert_schema(child, schema.fetch('items')) }
    when 'string'
      assert_kind_of String, value
      Time.iso8601(value) if schema['format'] == 'date-time'
      assert URI.parse(value).absolute?, "Expected absolute URI: #{value}" if schema['format'] == 'uri'
    when 'integer'
      assert_kind_of Integer, value
    when 'boolean'
      assert_includes [true, false], value
    else
      flunk "Unhandled schema type #{schema['type']}"
    end
  end
end
