FactoryBot.define do
  factory :version do
    package
    sequence(:number) { |n| "1.0.#{n}" }
    published_at { 1.day.ago }

    trait :with_sbom do
      distro_name { "Alpine Linux v3.17" }
      syft_version { "v0.70.0" }
      artifacts_count { 42 }
    end

    trait :recent do
      published_at { 1.day.ago }
    end

    trait :old do
      published_at { 30.days.ago }
    end

    trait :outdated do
      syft_version { "v0.60.0" }
    end
  end
end
