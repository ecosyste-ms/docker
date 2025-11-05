FactoryBot.define do
  factory :package do
    sequence(:name) { |n| "package-#{n}" }
    description { "A test package" }
    latest_release_number { "1.0.0" }
    latest_release_published_at { 1.day.ago }
    has_sbom { false }
    dependencies_count { 0 }
    versions_count { 0 }

    trait :with_sbom do
      has_sbom { true }
    end

    trait :redis do
      name { "redis" }
      description { "Redis is an open source in-memory data structure store" }
      latest_release_number { "7.0.5" }
      has_sbom { true }
      dependencies_count { 10 }
    end

    trait :nginx do
      name { "nginx" }
      description { "nginx web server" }
      latest_release_number { "1.23.3" }
      has_sbom { false }
    end

    trait :popular do
      downloads { 1000000 }
    end
  end
end
