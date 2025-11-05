FactoryBot.define do
  factory :dependency do
    version
    package
    ecosystem { "npm" }
    sequence(:package_name) { |n| "package-#{n}" }
    requirements { "^1.0.0" }
    sequence(:purl) { |n| "pkg:npm/package-#{n}@1.0.0" }

    trait :npm do
      ecosystem { "npm" }
      purl { "pkg:npm/#{package_name}@#{requirements}" }
    end

    trait :maven do
      ecosystem { "maven" }
      purl { "pkg:maven/#{package_name}@#{requirements}" }
    end

    trait :gem do
      ecosystem { "gem" }
      purl { "pkg:gem/#{package_name}@#{requirements}" }
    end

    trait :express do
      ecosystem { "npm" }
      package_name { "express" }
      requirements { "4.18.2" }
      purl { "pkg:npm/express@4.18.2" }
    end

    trait :lodash do
      ecosystem { "npm" }
      package_name { "lodash" }
      requirements { "4.17.21" }
      purl { "pkg:npm/lodash@4.17.21" }
    end
  end
end
