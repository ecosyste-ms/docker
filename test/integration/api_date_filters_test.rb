require "test_helper"

class ApiDateFiltersTest < ActionDispatch::IntegrationTest
  setup do
    @cutoff = Time.utc(2026, 1, 15, 12)
    @older = @cutoff - 1.day
  end

  %w[created_at updated_at].each do |column|
    test "distro listings filter by #{column} inclusively" do
      records = [-1, 0, 1].map do |offset|
        create(:distro, **timestamps(column, offset))
      end

      get api_v1_distros_path, params: { filter_for(column) => @cutoff.iso8601 }, as: :json

      assert_response :success
      assert_equal records.drop(1).map(&:slug).sort, response.parsed_body.map { |distro| distro['slug'] }.sort
    end

    test "distro version listings filter by #{column} inclusively" do
      distro = create(:distro)
      package = create(:package)
      records = [-1, 0, 1].map do |offset|
        create(:version, package: package, distro_name: distro.pretty_name, **timestamps(column, offset))
      end
      create(:version, package: package, distro_name: 'Another Linux', **timestamps(column, 1))

      get api_v1_distro_versions_path(distro.slug), params: { filter_for(column) => @cutoff.iso8601 }, as: :json

      assert_response :success
      assert_equal records.drop(1).map(&:number).sort, response.parsed_body.map { |version| version['number'] }.sort
    end

    test "package usage listings filter by #{column} inclusively" do
      records = [-1, 0, 1].map do |offset|
        create(:package_usage, ecosystem: 'npm', **timestamps(column, offset))
      end
      create(:package_usage, ecosystem: 'gem', **timestamps(column, 1))

      get api_v1_ecosystem_package_usages_path('npm'), params: { filter_for(column) => @cutoff.iso8601 }, as: :json

      assert_response :success
      assert_equal records.drop(1).map(&:name).sort, response.parsed_body.map { |usage| usage['name'] }.sort
    end
  end

  %w[created_at updated_at published_at].each do |column|
    test "package version listings filter by #{column} inclusively" do
      package = create(:package, name: 'library/redis')
      records = [-1, 0, 1].map do |offset|
        create(:version, package: package, published_at: @older, **timestamps(column, offset))
      end
      create(:version, **timestamps(column, 1))

      get api_v1_package_versions_path(package.name), params: { filter_for(column) => @cutoff.iso8601 }, as: :json

      assert_response :success
      assert_equal records.drop(1).map(&:number).sort, response.parsed_body.map { |version| version['number'] }.sort
    end
  end

  test "package version date filters combine" do
    package = create(:package)
    matching = create(:version, package: package, created_at: @cutoff, updated_at: @cutoff, published_at: @cutoff)
    %i[created_at updated_at published_at].each do |column|
      attributes = { created_at: @cutoff, updated_at: @cutoff, published_at: @cutoff }.merge(column => @older)
      create(:version, package: package, **attributes)
    end
    create(:version, package: package, created_at: @cutoff, updated_at: @cutoff, published_at: nil)

    get api_v1_package_versions_path(package.name), params: {
      created_after: @cutoff.iso8601,
      updated_after: @cutoff.iso8601,
      published_after: @cutoff.iso8601
    }, as: :json

    assert_response :success
    assert_equal [matching.number], response.parsed_body.map { |version| version['number'] }
  end

  def timestamps(column, offset)
    { created_at: @older, updated_at: @older }.merge(column.to_sym => @cutoff + offset)
  end

  def filter_for(column)
    column.sub('_at', '_after')
  end
end
