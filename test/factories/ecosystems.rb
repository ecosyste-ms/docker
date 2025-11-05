FactoryBot.define do
  factory :ecosystem do
    sequence(:name) { |n| "ecosystem-#{n}" }
    packages_count { 100 }
    total_downloads { 50000 }

    trait :npm do
      name { 'npm' }
      packages_count { 1000 }
      total_downloads { 5000000 }
    end

    trait :maven do
      name { 'maven' }
      packages_count { 500 }
      total_downloads { 2000000 }
    end

    trait :gem do
      name { 'gem' }
      packages_count { 200 }
      total_downloads { 800000 }
    end

    trait :pypi do
      name { 'pypi' }
      packages_count { 300 }
      total_downloads { 1500000 }
    end
  end
end
