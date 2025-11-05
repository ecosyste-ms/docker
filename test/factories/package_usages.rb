FactoryBot.define do
  factory :package_usage do
    sequence(:name) { |n| "package-#{n}" }
    ecosystem { 'npm' }
    dependents_count { 100 }
    downloads_count { 10000 }

    trait :npm do
      ecosystem { 'npm' }
    end

    trait :maven do
      ecosystem { 'maven' }
    end

    trait :gem do
      ecosystem { 'gem' }
    end

    trait :pypi do
      ecosystem { 'pypi' }
    end

    trait :popular do
      dependents_count { 5000 }
      downloads_count { 1000000 }
    end
  end
end
