FactoryBot.define do
  factory :distro do
    sequence(:pretty_name) { |n| "Test Linux v#{n}.0" }
    sequence(:name) { |n| "Test Linux #{n}" }
    sequence(:id_field) { |n| "testlinux#{n}" }
    version_id { "1.0" }
    id_like { "debian" }
    versions_count { 0 }
    total_downloads { 0 }

    trait :alpine do
      slug { "alpine-3-17" }
      pretty_name { "Alpine Linux v3.17" }
      name { "Alpine Linux" }
      id_field { "alpine" }
      version_id { "3.17" }
    end

    trait :debian do
      slug { "debian-12" }
      pretty_name { "Debian GNU/Linux 12 (bookworm)" }
      name { "Debian GNU/Linux" }
      id_field { "debian" }
      version_id { "12" }
      version_codename { "bookworm" }
      home_url { "https://www.debian.org/" }
    end

    trait :ubuntu do
      slug { "ubuntu-22-04" }
      pretty_name { "Ubuntu 22.04.1 LTS" }
      name { "Ubuntu" }
      id_field { "ubuntu" }
      version_id { "22.04" }
      version_codename { "jammy" }
      home_url { "https://www.ubuntu.com/" }
      support_url { "https://help.ubuntu.com/" }
      bug_report_url { "https://bugs.launchpad.net/ubuntu/" }
    end

    trait :ubuntu_focal do
      slug { "ubuntu-20-04" }
      pretty_name { "Ubuntu 20.04 LTS" }
      name { "Ubuntu" }
      id_field { "ubuntu" }
      version_id { "20.04" }
      version_codename { "focal" }
    end
  end
end
