FactoryBot.define do
  factory :sbom do
    version
    data do
      {
        "distro" => {
          "prettyName" => "Alpine Linux v3.17",
          "name" => "alpine",
          "id" => "alpine",
          "versionID" => "3.17.0"
        },
        "descriptor" => {
          "name" => "syft",
          "version" => "v0.70.0"
        },
        "artifacts" => [
          {
            "name" => "test-package",
            "version" => "1.0.0",
            "purl" => "pkg:npm/test-package@1.0.0"
          }
        ]
      }
    end

    trait :alpine do
      data do
        {
          "distro" => {
            "prettyName" => "Alpine Linux v3.17",
            "name" => "alpine"
          },
          "descriptor" => { "version" => "v0.70.0" },
          "artifacts" => []
        }
      end
    end

    trait :debian do
      data do
        {
          "distro" => {
            "prettyName" => "Debian GNU/Linux 12 (bookworm)",
            "name" => "debian"
          },
          "descriptor" => { "version" => "v0.70.0" },
          "artifacts" => []
        }
      end
    end
  end
end
