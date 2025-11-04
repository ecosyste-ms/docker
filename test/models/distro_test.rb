require "test_helper"

class DistroTest < ActiveSupport::TestCase
  test "requires pretty_name" do
    distro = Distro.new
    assert_not distro.valid?
    assert_includes distro.errors[:pretty_name], "can't be blank"
  end

  test "generates slug from pretty_name on validation" do
    distro = Distro.new(pretty_name: "Ubuntu 22.04.1 LTS")
    distro.valid?
    assert_equal "ubuntu-22-04-1-lts", distro.slug
  end

  test "slug is unique" do
    Distro.create!(pretty_name: "Ubuntu 22.04 LTS")
    duplicate = Distro.new(pretty_name: "Ubuntu 22.04 LTS")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "generate_slug handles special characters" do
    distro = Distro.new(pretty_name: "Debian GNU/Linux 12 (bookworm)")
    distro.generate_slug
    assert_equal "debian-gnu-linux-12-bookworm", distro.slug
  end

  test "generate_slug removes leading and trailing hyphens" do
    distro = Distro.new(pretty_name: "---Test Distro---")
    distro.generate_slug
    assert_equal "test-distro", distro.slug
  end

  test "parse_os_release extracts all fields" do
    content = <<~OS_RELEASE
      ID=ubuntu
      NAME="Ubuntu"
      VERSION_ID="22.04"
      PRETTY_NAME="Ubuntu 22.04.1 LTS"
      VERSION_CODENAME=jammy
      HOME_URL="https://www.ubuntu.com/"
      SUPPORT_URL="https://help.ubuntu.com/"
      BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
    OS_RELEASE

    attributes = Distro.parse_os_release(content)

    assert_equal "ubuntu", attributes[:id_field]
    assert_equal "Ubuntu", attributes[:name]
    assert_equal "22.04", attributes[:version_id]
    assert_equal "Ubuntu 22.04.1 LTS", attributes[:pretty_name]
    assert_equal "jammy", attributes[:version_codename]
    assert_equal "https://www.ubuntu.com/", attributes[:home_url]
    assert_equal "https://help.ubuntu.com/", attributes[:support_url]
    assert_equal "https://bugs.launchpad.net/ubuntu/", attributes[:bug_report_url]
  end

  test "parse_os_release handles missing fields" do
    content = <<~OS_RELEASE
      PRETTY_NAME="Minimal Distro"
    OS_RELEASE

    attributes = Distro.parse_os_release(content)

    assert_equal "Minimal Distro", attributes[:pretty_name]
    assert_nil attributes[:id_field]
    assert_nil attributes[:version_id]
  end

  test "parse_os_release removes quotes from values" do
    content = <<~OS_RELEASE
      NAME="Ubuntu"
      VERSION_ID='22.04'
      ID=ubuntu
    OS_RELEASE

    attributes = Distro.parse_os_release(content)

    assert_equal "Ubuntu", attributes[:name]
    assert_equal "22.04", attributes[:version_id]
    assert_equal "ubuntu", attributes[:id_field]
  end

  test "parse_os_release skips empty lines and comments" do
    content = <<~OS_RELEASE
      # This is a comment
      PRETTY_NAME="Test Distro"

      NAME="Test"
      # Another comment
    OS_RELEASE

    attributes = Distro.parse_os_release(content)

    assert_equal "Test Distro", attributes[:pretty_name]
    assert_equal "Test", attributes[:name]
  end

  test "grouping_key returns id_field when name matches" do
    distro = Distro.new(
      pretty_name: "Debian GNU/Linux 12 (bookworm)",
      name: "Debian GNU/Linux",
      id_field: "debian"
    )
    assert_equal "debian", distro.grouping_key
  end

  test "grouping_key returns name when different from id_field" do
    distro = Distro.new(
      pretty_name: "Pengwin",
      name: "Pengwin",
      id_field: "debian"
    )
    assert_equal "pengwin", distro.grouping_key
  end

  test "grouping_key returns name when id_field is missing" do
    distro = Distro.new(
      pretty_name: "Custom Distro",
      name: "Custom"
    )
    assert_equal "custom", distro.grouping_key
  end

  test "grouping_key returns id_field when name is missing" do
    distro = Distro.new(
      pretty_name: "Test",
      id_field: "test"
    )
    assert_equal "test", distro.grouping_key
  end

  test "grouping_key handles case variations" do
    distro = Distro.new(
      pretty_name: "Ubuntu 22.04",
      name: "Ubuntu",
      id_field: "ubuntu"
    )
    assert_equal "ubuntu", distro.grouping_key
  end

  test "update_versions_count counts matching Version records" do
    distro = Distro.create!(
      pretty_name: "Ubuntu 22.04.1 LTS",
      name: "Ubuntu",
      id_field: "ubuntu"
    )

    # Create a package to associate versions with
    package = Package.create!(name: "test-package")

    # Create versions with matching distro_name
    3.times do |i|
      Version.create!(
        package: package,
        number: "1.#{i}.0",
        distro_name: "Ubuntu 22.04.1 LTS"
      )
    end

    # Create version with different distro_name
    Version.create!(
      package: package,
      number: "2.0.0",
      distro_name: "Ubuntu 20.04 LTS"
    )

    distro.update_versions_count

    assert_equal 3, distro.versions_count
  end

  test "update_versions_count sets to zero when no matching versions" do
    distro = Distro.create!(
      pretty_name: "Alpine Linux v3.17",
      name: "Alpine Linux",
      id_field: "alpine"
    )

    distro.update_versions_count

    assert_equal 0, distro.versions_count
  end

  test "update_all_versions_counts updates all distros" do
    distro1 = Distro.create!(pretty_name: "Debian GNU/Linux 12 (bookworm)")
    distro2 = Distro.create!(pretty_name: "Ubuntu 22.04 LTS")

    package = Package.create!(name: "test-package")

    2.times do |i|
      Version.create!(
        package: package,
        number: "1.#{i}.0",
        distro_name: "Debian GNU/Linux 12 (bookworm)"
      )
    end

    Version.create!(
      package: package,
      number: "2.0.0",
      distro_name: "Ubuntu 22.04 LTS"
    )

    Distro.update_all_versions_counts

    assert_equal 2, distro1.reload.versions_count
    assert_equal 1, distro2.reload.versions_count
  end

  test "has_many versions relationship works" do
    distro = Distro.create!(
      pretty_name: "Ubuntu 22.04.1 LTS",
      name: "Ubuntu",
      id_field: "ubuntu"
    )

    package = Package.create!(name: "test-package")

    version1 = Version.create!(
      package: package,
      number: "1.0.0",
      distro_name: "Ubuntu 22.04.1 LTS"
    )

    version2 = Version.create!(
      package: package,
      number: "1.1.0",
      distro_name: "Ubuntu 22.04.1 LTS"
    )

    # Different distro
    Version.create!(
      package: package,
      number: "2.0.0",
      distro_name: "Debian GNU/Linux 12 (bookworm)"
    )

    assert_equal 2, distro.versions.count
    assert_includes distro.versions, version1
    assert_includes distro.versions, version2
  end

  test "parse_os_release extracts ID_LIKE" do
    content = <<~OS_RELEASE
      PRETTY_NAME="Pengwin"
      NAME="Pengwin"
      ID=debian
      ID_LIKE=debian
      VERSION_ID="11"
    OS_RELEASE

    attributes = Distro.parse_os_release(content)

    assert_equal "debian", attributes[:id_like]
  end

  test "related_distros returns distros matching ID_LIKE" do
    # Create base distro
    debian11 = Distro.create!(
      pretty_name: "Debian GNU/Linux 11 (bullseye)",
      name: "Debian GNU/Linux",
      id_field: "debian",
      version_id: "11"
    )

    debian12 = Distro.create!(
      pretty_name: "Debian GNU/Linux 12 (bookworm)",
      name: "Debian GNU/Linux",
      id_field: "debian",
      version_id: "12"
    )

    # Create derivative distro
    pengwin = Distro.create!(
      pretty_name: "Pengwin",
      name: "Pengwin",
      id_field: "debian",
      id_like: "debian",
      version_id: "11"
    )

    # Create unrelated distro
    Distro.create!(
      pretty_name: "Ubuntu 22.04 LTS",
      name: "Ubuntu",
      id_field: "ubuntu"
    )

    related = pengwin.related_distros

    assert_equal 2, related.count
    assert_includes related, debian11
    assert_includes related, debian12
  end

  test "related_distros handles multiple space-separated IDs" do
    debian = Distro.create!(
      pretty_name: "Debian GNU/Linux 12 (bookworm)",
      name: "Debian GNU/Linux",
      id_field: "debian"
    )

    ubuntu = Distro.create!(
      pretty_name: "Ubuntu 22.04 LTS",
      name: "Ubuntu",
      id_field: "ubuntu"
    )

    # Distro that is like both debian and ubuntu
    custom = Distro.create!(
      pretty_name: "Custom Distro",
      name: "Custom",
      id_field: "custom",
      id_like: "debian ubuntu"
    )

    related = custom.related_distros

    assert_equal 2, related.count
    assert_includes related, debian
    assert_includes related, ubuntu
  end

  test "related_distros returns empty when id_like is blank" do
    distro = Distro.create!(
      pretty_name: "Ubuntu 22.04 LTS",
      name: "Ubuntu",
      id_field: "ubuntu"
    )

    assert_equal 0, distro.related_distros.count
  end

  test "likely_docker_image returns debian with codename" do
    distro = Distro.new(
      pretty_name: "Debian GNU/Linux 12 (bookworm)",
      id_field: "debian",
      version_id: "12",
      version_codename: "bookworm"
    )

    result = distro.likely_docker_image
    assert_equal "debian:bookworm", result[:image]
    assert_equal "https://hub.docker.com/_/debian", result[:url]
  end

  test "likely_docker_image returns ubuntu with codename" do
    distro = Distro.new(
      pretty_name: "Ubuntu 22.04 LTS",
      id_field: "ubuntu",
      version_id: "22.04",
      version_codename: "jammy"
    )

    result = distro.likely_docker_image
    assert_equal "ubuntu:jammy", result[:image]
    assert_equal "https://hub.docker.com/_/ubuntu", result[:url]
  end

  test "likely_docker_image returns alpine with version_id" do
    distro = Distro.new(
      pretty_name: "Alpine Linux v3.17",
      id_field: "alpine",
      version_id: "3.17"
    )

    result = distro.likely_docker_image
    assert_equal "alpine:3.17", result[:image]
    assert_equal "https://hub.docker.com/_/alpine", result[:url]
  end

  test "likely_docker_image returns fedora with version_id" do
    distro = Distro.new(
      pretty_name: "Fedora Linux 40",
      id_field: "fedora",
      version_id: "40"
    )

    result = distro.likely_docker_image
    assert_equal "fedora:40", result[:image]
    assert_equal "https://hub.docker.com/_/fedora", result[:url]
  end

  test "likely_docker_image returns nil for unknown distro" do
    distro = Distro.new(
      pretty_name: "Custom Distro",
      id_field: "custom"
    )

    result = distro.likely_docker_image
    assert_nil result
  end

  test "likely_docker_image returns nil when no id_field" do
    distro = Distro.new(
      pretty_name: "Custom Distro",
      name: "Custom"
    )

    result = distro.likely_docker_image
    assert_nil result
  end

  test "likely_docker_image includes package_name" do
    distro = Distro.new(
      pretty_name: "Debian GNU/Linux 12 (bookworm)",
      id_field: "debian",
      version_id: "12",
      version_codename: "bookworm"
    )

    result = distro.likely_docker_image
    assert_equal "debian", result[:package_name]
  end

  test "likely_package finds library/debian package" do
    distro = Distro.create!(
      pretty_name: "Debian GNU/Linux 12 (bookworm)",
      id_field: "debian",
      version_id: "12",
      version_codename: "bookworm"
    )

    package = Package.create!(name: "library/debian")

    result = distro.likely_package
    assert_equal package, result
  end

  test "likely_package finds debian package without library prefix" do
    distro = Distro.create!(
      pretty_name: "Debian GNU/Linux 12 (bookworm)",
      id_field: "debian",
      version_id: "12",
      version_codename: "bookworm"
    )

    package = Package.create!(name: "debian")

    result = distro.likely_package
    assert_equal package, result
  end

  test "likely_package returns nil when package not found" do
    distro = Distro.create!(
      pretty_name: "Debian GNU/Linux 12 (bookworm)",
      id_field: "debian",
      version_id: "12",
      version_codename: "bookworm"
    )

    result = distro.likely_package
    assert_nil result
  end

  test "likely_package returns nil when no docker image" do
    distro = Distro.create!(
      pretty_name: "Custom Distro",
      name: "Custom"
    )

    result = distro.likely_package
    assert_nil result
  end

  test "missing_from_versions finds distros in versions but not in distros table" do
    # Create a distro that exists
    Distro.create!(pretty_name: "Ubuntu 22.04 LTS")

    # Create versions with various distro names
    package = Package.create!(name: "test/package")

    # This one has matching distro
    Version.create!(package: package, number: "1.0.0", distro_name: "Ubuntu 22.04 LTS")
    Version.create!(package: package, number: "1.0.1", distro_name: "Ubuntu 22.04 LTS")

    # These don't have matching distros
    Version.create!(package: package, number: "2.0.0", distro_name: "Debian GNU/Linux 12 (bookworm)")
    Version.create!(package: package, number: "2.0.1", distro_name: "Debian GNU/Linux 12 (bookworm)")
    Version.create!(package: package, number: "2.0.2", distro_name: "Debian GNU/Linux 12 (bookworm)")
    Version.create!(package: package, number: "3.0.0", distro_name: "Alpine Linux v3.17")

    missing = Distro.missing_from_versions

    # Should return array of [name, count] pairs
    assert_equal 2, missing.count

    # Convert to hash for easier assertion
    missing_hash = missing.to_h
    assert_equal 3, missing_hash["Debian GNU/Linux 12 (bookworm)"]
    assert_equal 1, missing_hash["Alpine Linux v3.17"]

    # Should be sorted by count descending
    assert_equal "Debian GNU/Linux 12 (bookworm)", missing.first[0]
    assert_equal 3, missing.first[1]
  end

  test "missing_from_versions returns empty when all distros exist" do
    package = Package.create!(name: "test/package")

    # Create distro
    Distro.create!(pretty_name: "Ubuntu 22.04 LTS")

    # Create version with matching distro
    Version.create!(package: package, number: "1.0.0", distro_name: "Ubuntu 22.04 LTS")

    missing = Distro.missing_from_versions

    assert_equal 0, missing.count
  end

  test "missing_from_versions ignores nil and empty distro_names" do
    package = Package.create!(name: "test/package")

    # Create versions without distro_name
    Version.create!(package: package, number: "1.0.0", distro_name: nil)
    Version.create!(package: package, number: "1.0.1", distro_name: "")

    missing = Distro.missing_from_versions

    assert_equal 0, missing.count
  end

  test "guess_docker_image_from_name handles Alpine Linux" do
    assert_equal "alpine:3.20", Distro.guess_docker_image_from_name("Alpine Linux v3.20")
    assert_equal "alpine:3.17", Distro.guess_docker_image_from_name("Alpine Linux v3.17")
  end

  test "guess_docker_image_from_name handles Debian" do
    assert_equal "debian:12", Distro.guess_docker_image_from_name("Debian GNU/Linux 12 (bookworm)")
    assert_equal "debian:11", Distro.guess_docker_image_from_name("Debian GNU/Linux 11 (bullseye)")
  end

  test "guess_docker_image_from_name handles Ubuntu" do
    assert_equal "ubuntu:22.04", Distro.guess_docker_image_from_name("Ubuntu 22.04.1 LTS")
    assert_equal "ubuntu:20.04", Distro.guess_docker_image_from_name("Ubuntu 20.04 LTS")
  end

  test "guess_docker_image_from_name handles Fedora" do
    assert_equal "fedora:40", Distro.guess_docker_image_from_name("Fedora Linux 40")
    assert_equal "fedora:39", Distro.guess_docker_image_from_name("Fedora CoreOS 39")
  end

  test "guess_docker_image_from_name returns nil for Distroless (not on Docker Hub)" do
    assert_nil Distro.guess_docker_image_from_name("Distroless")
  end

  test "guess_docker_image_from_name handles Oracle Linux" do
    assert_equal "oraclelinux:8", Distro.guess_docker_image_from_name("Oracle Linux Server 8.5")
  end

  test "guess_docker_image_from_name handles Red Hat" do
    assert_equal "redhat/ubi8", Distro.guess_docker_image_from_name("Red Hat Enterprise Linux 8.7 (Ootpa)")
  end

  test "guess_docker_image_from_name returns nil for unknown pattern" do
    assert_nil Distro.guess_docker_image_from_name("Custom Unknown Distro 1.0")
  end
end
