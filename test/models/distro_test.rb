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
      slug: "debian-12",
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

  test "update_total_downloads sums downloads from unique packages" do
    distro = Distro.create!(
      pretty_name: "Ubuntu 22.04.1 LTS",
      name: "Ubuntu",
      id_field: "ubuntu"
    )

    package1 = Package.create!(name: "redis", downloads: 1000000)
    package2 = Package.create!(name: "nginx", downloads: 500000)
    package3 = Package.create!(name: "postgres", downloads: 750000)

    # Create versions for this distro
    Version.create!(package: package1, number: "7.0", distro_name: "Ubuntu 22.04.1 LTS")
    Version.create!(package: package1, number: "6.0", distro_name: "Ubuntu 22.04.1 LTS")
    Version.create!(package: package2, number: "1.23", distro_name: "Ubuntu 22.04.1 LTS")
    Version.create!(package: package3, number: "15.0", distro_name: "Ubuntu 22.04.1 LTS")

    # Create version for different distro
    Version.create!(package: package1, number: "5.0", distro_name: "Debian GNU/Linux 12 (bookworm)")

    distro.update_total_downloads

    # Should sum unique packages only: 1000000 + 500000 + 750000 = 2250000
    assert_equal 2250000, distro.total_downloads
  end

  test "update_total_downloads handles nil downloads" do
    distro = Distro.create!(pretty_name: "Alpine Linux v3.17")

    package1 = Package.create!(name: "test1", downloads: 100000)
    package2 = Package.create!(name: "test2", downloads: nil)

    Version.create!(package: package1, number: "1.0", distro_name: "Alpine Linux v3.17")
    Version.create!(package: package2, number: "1.0", distro_name: "Alpine Linux v3.17")

    distro.update_total_downloads

    assert_equal 100000, distro.total_downloads
  end

  test "update_total_downloads sets to zero when no packages" do
    distro = Distro.create!(pretty_name: "Alpine Linux v3.17")

    distro.update_total_downloads

    assert_equal 0, distro.total_downloads
  end

  test "update_all_total_downloads updates all distros" do
    distro1 = Distro.create!(pretty_name: "Debian GNU/Linux 12 (bookworm)")
    distro2 = Distro.create!(pretty_name: "Ubuntu 22.04 LTS")

    package1 = Package.create!(name: "redis", downloads: 1000000)
    package2 = Package.create!(name: "nginx", downloads: 500000)

    Version.create!(package: package1, number: "7.0-debian", distro_name: "Debian GNU/Linux 12 (bookworm)")
    Version.create!(package: package2, number: "1.23", distro_name: "Debian GNU/Linux 12 (bookworm)")
    Version.create!(package: package1, number: "7.0-ubuntu", distro_name: "Ubuntu 22.04 LTS")

    Distro.update_all_total_downloads

    assert_equal 1500000, distro1.reload.total_downloads
    assert_equal 1000000, distro2.reload.total_downloads
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
    Distro.create!(
      slug: 'ubuntu-22-04',
      pretty_name: "Ubuntu 22.04 LTS",
      id_field: 'ubuntu',
      version_id: '22.04'
    )

    # Create versions with various distro names
    package = Package.create!(name: "test/package")

    # This one has matching distro (exact match)
    Version.create!(package: package, number: "1.0.0", distro_name: "Ubuntu 22.04 LTS")
    Version.create!(package: package, number: "1.0.1", distro_name: "Ubuntu 22.04 LTS")

    # These don't have matching distros - need SBOM data
    debian_v1 = Version.create!(package: package, number: "2.0.0", distro_name: "Debian GNU/Linux 12 (bookworm)")
    debian_v1.create_sbom_record!(data: {
      'distro' => { 'id' => 'debian', 'versionID' => '12', 'prettyName' => 'Debian GNU/Linux 12 (bookworm)' }
    })

    debian_v2 = Version.create!(package: package, number: "2.0.1", distro_name: "Debian GNU/Linux 12 (bookworm)")
    debian_v2.create_sbom_record!(data: {
      'distro' => { 'id' => 'debian', 'versionID' => '12', 'prettyName' => 'Debian GNU/Linux 12 (bookworm)' }
    })

    debian_v3 = Version.create!(package: package, number: "2.0.2", distro_name: "Debian GNU/Linux 12 (bookworm)")
    debian_v3.create_sbom_record!(data: {
      'distro' => { 'id' => 'debian', 'versionID' => '12', 'prettyName' => 'Debian GNU/Linux 12 (bookworm)' }
    })

    alpine_v = Version.create!(package: package, number: "3.0.0", distro_name: "Alpine Linux v3.17")
    alpine_v.create_sbom_record!(data: {
      'distro' => { 'id' => 'alpine', 'versionID' => '3.17', 'prettyName' => 'Alpine Linux v3.17' }
    })

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

  # Grouping tests
  test "grouping_key extracts base name from slug" do
    distro = Distro.new(slug: "ubuntu-22-04")
    assert_equal "ubuntu", distro.grouping_key
  end

  test "grouping_key handles multi-part names like ubuntu-kylin" do
    distro = Distro.new(slug: "ubuntu-kylin-22-04")
    assert_equal "ubuntu-kylin", distro.grouping_key
  end

  test "grouping_key handles variant names like fedora-container" do
    distro = Distro.new(slug: "fedora-container-39")
    assert_equal "fedora-container", distro.grouping_key
  end

  test "grouping_key handles bodhi separately from ubuntu" do
    bodhi = Distro.new(slug: "bodhi-20-04")
    ubuntu = Distro.new(slug: "ubuntu-20-04")

    assert_equal "bodhi", bodhi.grouping_key
    assert_equal "ubuntu", ubuntu.grouping_key
    assert_not_equal bodhi.grouping_key, ubuntu.grouping_key
  end

  test "group_display_name titleizes the grouping key" do
    assert_equal "Ubuntu", Distro.group_display_name("ubuntu", [])
    assert_equal "Ubuntu Kylin", Distro.group_display_name("ubuntu-kylin", [])
    assert_equal "Fedora Container", Distro.group_display_name("fedora-container", [])
    assert_equal "Bodhi", Distro.group_display_name("bodhi", [])
  end

  test "group_display_name does not show duplicated names" do
    debian_name = Distro.group_display_name("debian", [])
    assert_equal "Debian", debian_name
    refute_includes debian_name, "Debian Debian"
  end

  test "group_display_name does not include Discontinued prefix" do
    centos_name = Distro.group_display_name("centos", [])
    assert_equal "Centos", centos_name
    refute_includes centos_name, "Discontinued"
  end

  test "bodhi distro does not show as Ubuntu" do
    bodhi = Distro.new(slug: "bodhi-20-04", name: "Ubuntu", id_field: "ubuntu")
    ubuntu = Distro.new(slug: "ubuntu-20-04", name: "Ubuntu", id_field: "ubuntu")

    assert_not_equal bodhi.grouping_key, ubuntu.grouping_key
    assert_equal "Bodhi", Distro.group_display_name(bodhi.grouping_key, [bodhi])
  end

  test "discontinued distros should not have discontinued in slug" do
    centos = Distro.new(slug: "centos-8", discontinued: true)
    assert_equal "centos", centos.grouping_key
    refute_includes centos.slug, "discontinued"
  end

  # Import tests
  test "parse_and_create_distro generates correct slug from file path" do
    Dir.mktmpdir do |dir|
      os_release_dir = File.join(dir, 'os-release')
      FileUtils.mkdir_p(os_release_dir)

      ubuntu_dir = File.join(os_release_dir, 'ubuntu')
      FileUtils.mkdir_p(ubuntu_dir)
      File.write(File.join(ubuntu_dir, '22.04'), <<~OSRELEASE)
        NAME="Ubuntu"
        PRETTY_NAME="Ubuntu 22.04 LTS"
        VERSION_ID="22.04"
        ID=ubuntu
      OSRELEASE

      Distro.parse_and_create_distro(File.join(ubuntu_dir, '22.04'))
      ubuntu = Distro.find_by(slug: 'ubuntu-22-04')

      assert_not_nil ubuntu
      assert_equal 'ubuntu-22-04', ubuntu.slug
      assert_equal 'Ubuntu', ubuntu.name
      assert_equal '22.04', ubuntu.version_id
      assert_equal false, ubuntu.discontinued
    end
  end

  test "parse_and_create_distro handles discontinued distros" do
    Dir.mktmpdir do |dir|
      os_release_dir = File.join(dir, 'os-release')
      discontinued_dir = File.join(os_release_dir, 'discontinued', 'centos')
      FileUtils.mkdir_p(discontinued_dir)

      File.write(File.join(discontinued_dir, '8'), <<~OSRELEASE)
        NAME="CentOS Linux"
        PRETTY_NAME="CentOS Linux 8"
        VERSION_ID="8"
        ID=centos
      OSRELEASE

      Distro.parse_and_create_distro(File.join(discontinued_dir, '8'))
      centos = Distro.find_by(slug: 'centos-8')

      assert_not_nil centos
      assert_equal 'centos-8', centos.slug
      assert_equal true, centos.discontinued
      refute_includes centos.slug, 'discontinued'
    end
  end

  test "parse_and_create_distro handles variants" do
    Dir.mktmpdir do |dir|
      os_release_dir = File.join(dir, 'os-release')
      fedora_dir = File.join(os_release_dir, 'fedora', 'container')
      FileUtils.mkdir_p(fedora_dir)

      File.write(File.join(fedora_dir, '39'), <<~OSRELEASE)
        NAME="Fedora Linux"
        PRETTY_NAME="Fedora Linux 39"
        VERSION_ID="39"
        ID=fedora
        VARIANT="Container"
        VARIANT_ID="container"
      OSRELEASE

      Distro.parse_and_create_distro(File.join(fedora_dir, '39'))
      fedora = Distro.find_by(slug: 'fedora-container-39')

      assert_not_nil fedora
      assert_equal 'fedora-container-39', fedora.slug
      assert_equal 'Fedora Linux', fedora.name
      assert_equal '39', fedora.version_id
      assert_equal 'container', fedora.variant_id
    end
  end

  test "parse_and_create_distro handles ubuntu kylin separately from ubuntu" do
    Dir.mktmpdir do |dir|
      os_release_dir = File.join(dir, 'os-release')

      ubuntu_kylin_dir = File.join(os_release_dir, 'ubuntu_kylin')
      FileUtils.mkdir_p(ubuntu_kylin_dir)
      File.write(File.join(ubuntu_kylin_dir, '22.04'), <<~OSRELEASE)
        NAME="Ubuntu Kylin"
        PRETTY_NAME="Ubuntu 22.04 LTS"
        VERSION_ID="22.04"
        ID=ubuntu
      OSRELEASE

      ubuntu_dir = File.join(os_release_dir, 'ubuntu')
      FileUtils.mkdir_p(ubuntu_dir)
      File.write(File.join(ubuntu_dir, '22.04'), <<~OSRELEASE)
        NAME="Ubuntu"
        PRETTY_NAME="Ubuntu 22.04 LTS"
        VERSION_ID="22.04"
        ID=ubuntu
      OSRELEASE

      Distro.parse_and_create_distro(File.join(ubuntu_kylin_dir, '22.04'))
      Distro.parse_and_create_distro(File.join(ubuntu_dir, '22.04'))

      ubuntu_kylin = Distro.find_by(slug: 'ubuntu-kylin-22-04')
      ubuntu = Distro.find_by(slug: 'ubuntu-22-04')

      assert_not_nil ubuntu_kylin
      assert_not_nil ubuntu
      assert_not_equal ubuntu_kylin.slug, ubuntu.slug
      assert_equal 'ubuntu-kylin', ubuntu_kylin.grouping_key
      assert_equal 'ubuntu', ubuntu.grouping_key
    end
  end

  # Sync tests
  test "sync_from_github removes old distros with bad slugs" do
    Distro.create!(
      slug: 'discontinued-centos-8',
      pretty_name: 'CentOS Linux 8',
      name: 'CentOS Linux',
      id_field: 'centos',
      version_id: '8'
    )

    Distro.sync_from_github

    assert_nil Distro.find_by(slug: 'discontinued-centos-8')
    assert_not_nil Distro.find_by(slug: 'centos-8')
  end

  test "sync_from_github handles debian debian file correctly" do
    Distro.sync_from_github

    assert_nil Distro.find_by(slug: 'debian-debian')

    debian_unstable = Distro.find_by(slug: 'debian-unstable')
    assert_not_nil debian_unstable
    assert_equal 'debian', debian_unstable.grouping_key
  end

  test "missing_from_versions does not show versions that match by id and version_id" do
    distro = Distro.create!(
      slug: 'ubuntu-22-04',
      pretty_name: 'Ubuntu 22.04 LTS',
      name: 'Ubuntu',
      id_field: 'ubuntu',
      version_id: '22.04'
    )

    package = Package.create!(name: 'test/ubuntu')

    sbom_data = {
      'distro' => {
        'id' => 'ubuntu',
        'versionID' => '22.04',
        'prettyName' => 'Ubuntu 22.04.1 LTS'
      }
    }

    version = Version.create!(
      package: package,
      number: '1.0',
      distro_name: 'Ubuntu 22.04.1 LTS'
    )
    version.create_sbom_record!(data: sbom_data)

    missing = Distro.missing_from_versions

    # Ubuntu 22.04.1 LTS should NOT be in missing because it matches ubuntu-22-04 by ID + VERSION_ID
    missing_names = missing.map(&:first)
    refute_includes missing_names, 'Ubuntu 22.04.1 LTS'
  end

  test "missing_from_versions filters out versions with no version_id" do
    package = Package.create!(name: 'test/unknown')

    sbom_data = {
      'distro' => {
        'id' => 'debian',
        'prettyName' => 'Debian GNU/Linux trixie/sid',
        'name' => 'Debian GNU/Linux'
      }
    }

    version = Version.create!(
      package: package,
      number: '1.0',
      distro_name: 'Debian GNU/Linux trixie/sid'
    )
    version.create_sbom_record!(data: sbom_data)

    missing = Distro.missing_from_versions

    # Should not include versions without version_id
    missing_names = missing.map(&:first)
    refute_includes missing_names, 'Debian GNU/Linux trixie/sid'
  end
end
