require "test_helper"
require 'open3'

class VersionTest < ActiveSupport::TestCase
  context 'associations' do
    should belong_to(:package)
    should have_many(:dependencies).dependent(:delete_all)
  end

  context 'validations' do
    should validate_presence_of(:number)
  end
  

  context 'uniqueness validation' do
    setup do
      @package = Package.create!(name: 'test/package')
      @version = Version.create!(package: @package, number: '1.0.0')
    end

    should 'validate uniqueness of number scoped to package_id' do
      duplicate = Version.new(package: @package, number: '1.0.0')
      assert_not duplicate.valid?
      assert_includes duplicate.errors[:number], 'has already been taken'
    end

    should 'allow same version number for different packages' do
      other_package = Package.create!(name: 'other/package')
      other_version = Version.new(package: other_package, number: '1.0.0')
      assert other_version.valid?
    end
  end

  context 'instance methods' do
    setup do
      @package = Package.create!(name: 'test/package')
      @version = Version.create!(package: @package, number: '1.0.0')
    end

    context '#to_s' do
      should 'return the version number' do
        assert_equal '1.0.0', @version.to_s
      end
    end

    context '#to_param' do
      should 'return the version number' do
        assert_equal '1.0.0', @version.to_param
      end
    end

    context '#distro_record' do
      should 'find distro by distro_name' do
        @version.update!(distro_name: 'Ubuntu 22.04.1 LTS')
        distro = Distro.create!(pretty_name: 'Ubuntu 22.04.1 LTS')

        assert_equal distro, @version.distro_record
      end

      should 'return nil when distro_name is blank' do
        @version.update!(distro_name: nil)

        assert_nil @version.distro_record
      end

      should 'return nil when distro not found' do
        @version.update!(distro_name: 'Non-existent Distro')

        assert_nil @version.distro_record
      end
    end

    context '#distro_data' do
      should 'return distro object from sbom_data' do
        sbom_data = {
          'distro' => {
            'id' => 'ubuntu',
            'name' => 'Ubuntu',
            'prettyName' => 'Ubuntu 22.04.1 LTS',
            'version' => '22.04'
          }
        }
        @version.create_sbom_record!(data: sbom_data)

        result = @version.distro_data
        assert_equal 'ubuntu', result['id']
        assert_equal 'Ubuntu', result['name']
        assert_equal 'Ubuntu 22.04.1 LTS', result['prettyName']
      end

      should 'return nil when no sbom_data' do
        assert_nil @version.distro_data
      end
    end

    context 'SBOM related methods' do
      context 'when sbom_record is nil' do
        should 'return nil for distro' do
          assert_nil @version.distro
        end

        should 'return nil for syft_version' do
          assert_nil @version.syft_version
        end

        should 'return empty array for purls' do
          assert_equal [], @version.purls
        end

        should 'not be outdated' do
          assert_equal false, @version.outdated?
        end

        should 'return false for has_sbom?' do
          assert_not @version.has_sbom?
        end
      end

      context 'when sbom_record is present' do
        setup do
          @sbom_data = {
            'distro' => {
              'prettyName' => 'Ubuntu 20.04.5 LTS'
            },
            'descriptor' => {
              'version' => 'v0.70.0'
            },
            'artifacts' => [
              {
                'purl' => 'pkg:npm/express@4.18.2',
                'name' => 'express'
              },
              {
                'purl' => 'pkg:npm/lodash@4.17.21',
                'name' => 'lodash'
              },
              {
                'purl' => '',
                'name' => 'empty-purl'
              },
              {
                'purl' => 'pkg:npm/express@4.18.2',
                'name' => 'duplicate'
              }
            ]
          }
          @version.update!(distro_name: 'Ubuntu 20.04.5 LTS', syft_version: 'v0.70.0')
          @version.create_sbom_record!(data: @sbom_data)
        end

        should 'return distro from distro_name field' do
          assert_equal 'Ubuntu 20.04.5 LTS', @version.distro
        end

        should 'return syft_version from cached field' do
          assert_equal 'v0.70.0', @version.syft_version
        end

        should 'return unique sorted purls without blanks' do
          expected_purls = [
            'pkg:npm/express@4.18.2',
            'pkg:npm/lodash@4.17.21'
          ]
          assert_equal expected_purls, @version.purls
        end

        should 'check if outdated based on syft version' do
          Package.stubs(:syft_version).returns('v0.71.0')
          assert @version.outdated?

          Package.stubs(:syft_version).returns('v0.70.0')
          assert_not @version.outdated?
        end

        should 'return true for has_sbom?' do
          assert @version.has_sbom?
        end
      end
    end

    context '#parse_sbom_async' do
      should 'enqueue ParseSbomWorker with version id' do
        ParseSbomWorker.expects(:perform_async).with(@version.id)
        @version.parse_sbom_async
      end
    end

    context '#parse_sbom' do
      setup do
        @syft_output = {
          'distro' => {'prettyName' => 'Alpine Linux v3.17'},
          'descriptor' => {'version' => 'v0.70.0'},
          'artifacts' => [
            {'purl' => 'pkg:npm/express@4.18.2'}
          ]
        }.to_json
      end

      context 'when syft command succeeds' do
        setup do
          status_mock = mock('status')
          status_mock.stubs(:success?).returns(true)
          status_mock.stubs(:exitstatus).returns(0)
          Open3.expects(:capture2).with('timeout', '15m', 'syft', 'test/package:1.0.0', '--quiet', '--output', 'syft-json').returns([@syft_output, status_mock])
        end

        should 'create sbom_record and update last_synced_at' do
          freeze_time do
            assert_difference 'Sbom.count', 1 do
              @version.parse_sbom
            end
            @version.reload

            assert_not_nil @version.sbom_record
            assert_equal JSON.parse(@syft_output), @version.sbom_record.data
            assert_equal Time.now, @version.last_synced_at
          end
        end

        should 'update package has_sbom and dependencies_count' do
          @version.parse_sbom
          @package.reload

          assert @package.has_sbom
          assert_equal 1, @package.dependencies_count
          assert_not_nil @package.last_synced_at
        end

        should 'call save_dependencies' do
          @version.expects(:save_dependencies)
          @version.parse_sbom
        end
      end
      
      context 'with potentially dangerous package names' do
        setup do
          @dangerous_package = Package.create!(name: 'test/package"; echo "pwned')
          @dangerous_version = Version.create!(package: @dangerous_package, number: '1.0.0"; rm -rf /')
          
          status_mock = mock('status')
          status_mock.stubs(:success?).returns(true)
          
          # With Open3.capture2, the dangerous characters are passed as-is without shell interpretation
          image_name = 'test/package"; echo "pwned:1.0.0"; rm -rf /'
          Open3.expects(:capture2).with('timeout', '15m', 'syft', image_name, '--quiet', '--output', 'syft-json').returns([@syft_output, status_mock])
          status_mock.stubs(:exitstatus).returns(0)
        end
        
        should 'safely handle dangerous characters without shell interpretation' do
          @dangerous_version.parse_sbom
          # The dangerous characters are passed as a single argument to syft,
          # not interpreted by the shell, making this approach inherently safe
        end
      end

      context 'when syft command times out' do
        setup do
          status_mock = mock('status')
          status_mock.stubs(:success?).returns(false)
          status_mock.stubs(:exitstatus).returns(124)
          Open3.expects(:capture2).with('timeout', '15m', 'syft', 'test/package:1.0.0', '--quiet', '--output', 'syft-json').returns(['', status_mock])
        end

        should 'handle timeout and update timestamp' do
          @version.expects(:puts).with(includes('Timeout'))
          freeze_time do
            @version.parse_sbom
            @version.reload

            assert_nil @version.sbom_record
            assert_equal Time.now, @version.last_synced_at
          end
        end
      end

      context 'when syft command fails' do
        setup do
          status_mock = mock('status')
          status_mock.stubs(:success?).returns(false)
          status_mock.stubs(:exitstatus).returns(1)
          Open3.expects(:capture2).with('timeout', '15m', 'syft', 'test/package:1.0.0', '--quiet', '--output', 'syft-json').returns(['', status_mock])
        end

        should 'handle error and update timestamp' do
          @version.update!(distro_name: 'Ubuntu', syft_version: 'v1.0.0', artifacts_count: 5)
          existing_sbom_record = @version.create_sbom_record!(data: {'existing' => 'data'})

          @version.expects(:puts)
          freeze_time do
            @version.parse_sbom
            @version.reload

            # Should keep existing data on error
            assert_equal existing_sbom_record.id, @version.sbom_record.id
            assert_equal 'Ubuntu', @version.distro_name
            assert_equal 'v1.0.0', @version.syft_version
            assert_equal 5, @version.artifacts_count
            assert_equal Time.now, @version.last_synced_at
          end
        end

        should 'handle error when no existing sbom data' do
          @version.expects(:puts)
          freeze_time do
            @version.parse_sbom
            @version.reload

            assert_nil @version.sbom_record
            assert_equal Time.now, @version.last_synced_at
          end
        end
      end
    end

    context '#save_dependencies' do
      setup do
        sbom_data = {
          'artifacts' => [
            {'purl' => 'pkg:npm/express@4.18.2'},
            {'purl' => 'pkg:maven/org.springframework/spring-core@5.3.23'},
            {'purl' => 'pkg:gem/rails@7.0.4'},
            {'purl' => 'invalid-purl'},
            {'purl' => ''}
          ]
        }
        @version.create_sbom_record!(data: sbom_data)
      end

      should 'delete existing dependencies and create new ones' do
        # Create existing dependency
        existing = Dependency.create!(
          version: @version,
          package: @package,
          ecosystem: 'npm',
          package_name: 'old-package',
          requirements: '1.0.0',
          purl: 'pkg:npm/old-package@1.0.0'
        )

        assert_difference 'Dependency.count', 2 do
          @version.save_dependencies
        end

        assert_not Dependency.exists?(existing.id)

        deps = @version.dependencies.order(:package_name)
        assert_equal 3, deps.count

        # Check npm dependency
        npm_dep = deps.find { |d| d.ecosystem == 'npm' }
        assert_equal 'express', npm_dep.package_name
        assert_equal '4.18.2', npm_dep.requirements
        assert_equal 'pkg:npm/express@4.18.2', npm_dep.purl

        # Check maven dependency with namespace
        maven_dep = deps.find { |d| d.ecosystem == 'maven' }
        assert_equal 'org.springframework:spring-core', maven_dep.package_name
        assert_equal '5.3.23', maven_dep.requirements

        # Check gem dependency
        gem_dep = deps.find { |d| d.ecosystem == 'gem' }
        assert_equal 'rails', gem_dep.package_name
        assert_equal '7.0.4', gem_dep.requirements
      end

      should 'handle dependencies without version' do
        sbom_data = {
          'artifacts' => [
            {'purl' => 'pkg:npm/express'}
          ]
        }
        @version.sbom_record.update!(data: sbom_data)

        @version.save_dependencies
        @version.reload

        deps = @version.dependencies
        assert_equal 1, deps.count

        dep = deps.first
        assert_equal '*', dep.requirements
      end

      should 'not create dependencies when purls array is empty' do
        @version.sbom_record.update!(data: {'artifacts' => []})

        assert_no_difference 'Dependency.count' do
          @version.save_dependencies
        end
      end
    end
    
  end
end
