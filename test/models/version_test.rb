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
  
  context 'scopes' do
    context '.needs_sbom_migration' do
      setup do
        @package = Package.create!(name: 'test/package')
      end
      
      should 'include versions with sbom data but no sbom_record' do
        v1 = Version.create!(package: @package, number: 'v1', sbom: { 'data' => 'test' })
        v2 = Version.create!(package: @package, number: 'v2', sbom: nil)
        v3 = Version.create!(package: @package, number: 'v3', sbom: { 'data' => 'test' })
        v3.create_sbom_record!(data: { 'data' => 'test' })
        
        versions_needing_migration = Version.needs_sbom_migration
        
        assert_includes versions_needing_migration, v1
        assert_not_includes versions_needing_migration, v2  # No sbom data
        assert_not_includes versions_needing_migration, v3  # Already has sbom_record
      end
    end
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
      context 'when sbom is nil' do
        setup do
          @version.sbom = nil
        end

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
      end

      context 'when sbom is present' do
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
          @version.sbom = @sbom_data
        end

        should 'return distro from sbom' do
          assert_equal 'Ubuntu 20.04.5 LTS', @version.distro
        end

        should 'return syft_version from sbom' do
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
          Open3.expects(:capture2).with('syft', 'test/package:1.0.0', '--quiet', '--output', 'syft-json').returns([@syft_output, status_mock])
        end

        should 'create sbom_record and update last_synced_at' do
          freeze_time do
            assert_difference 'Sbom.count', 1 do
              @version.parse_sbom
            end
            @version.reload

            # Should create sbom_record and clear old column
            assert_nil @version.sbom
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
          Open3.expects(:capture2).with('syft', image_name, '--quiet', '--output', 'syft-json').returns([@syft_output, status_mock])
        end
        
        should 'safely handle dangerous characters without shell interpretation' do
          @dangerous_version.parse_sbom
          # The dangerous characters are passed as a single argument to syft,
          # not interpreted by the shell, making this approach inherently safe
        end
      end

      context 'when syft command fails' do
        setup do
          status_mock = mock('status')
          status_mock.stubs(:success?).returns(false)
          status_mock.stubs(:exitstatus).returns(1)
          Open3.expects(:capture2).with('syft', 'test/package:1.0.0', '--quiet', '--output', 'syft-json').returns(['', status_mock])
        end

        should 'handle error and keep existing sbom data' do
          # Set up existing SBOM data
          existing_sbom = { 'existing' => 'data' }
          @version.update!(sbom: existing_sbom, distro_name: 'Ubuntu', syft_version: 'v1.0.0', artifacts_count: 5)
          
          @version.expects(:puts)
          freeze_time do
            @version.parse_sbom
            @version.reload

            # Should keep existing data on error
            assert_equal existing_sbom, @version.sbom
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

            # Should remain nil/empty when no existing data
            assert_nil @version.sbom
            assert_nil @version.distro_name
            assert_nil @version.syft_version
            assert_equal 0, @version.artifacts_count
            assert_equal Time.now, @version.last_synced_at
          end
        end
      end
    end

    context '#save_dependencies' do
      setup do
        @version.sbom = {
          'artifacts' => [
            {'purl' => 'pkg:npm/express@4.18.2'},
            {'purl' => 'pkg:maven/org.springframework/spring-core@5.3.23'},
            {'purl' => 'pkg:gem/rails@7.0.4'},
            {'purl' => 'invalid-purl'},
            {'purl' => ''}
          ]
        }
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
        @version.sbom = {
          'artifacts' => [
            {'purl' => 'pkg:npm/express'}
          ]
        }

        @version.save_dependencies
        @version.reload
        
        deps = @version.dependencies
        assert_equal 1, deps.count
        
        dep = deps.first
        assert_equal '*', dep.requirements
      end

      should 'not create dependencies when purls array is empty' do
        @version.sbom = {'artifacts' => []}

        assert_no_difference 'Dependency.count' do
          @version.save_dependencies
        end
      end
    end
    
    context '#migrate_sbom_to_table' do
      setup do
        @sbom_data = {
          'distro' => {'prettyName' => 'Ubuntu 20.04'},
          'descriptor' => {'version' => 'v0.70.0'},
          'artifacts' => [
            {'purl' => 'pkg:npm/express@4.18.2'},
            {'purl' => 'pkg:npm/lodash@4.17.21'}
          ]
        }
      end
      
      should 'migrate sbom data to new table and clear old column' do
        @version.sbom = @sbom_data
        @version.save!
        
        assert_difference 'Sbom.count', 1 do
          result = @version.migrate_sbom_to_table
          assert result
        end
        
        @version.reload
        assert_equal 'Ubuntu 20.04', @version.distro_name
        assert_equal 'v0.70.0', @version.syft_version
        assert_equal 2, @version.artifacts_count
        
        assert_not_nil @version.sbom_record
        assert_equal @sbom_data, @version.sbom_record.data
        
        # Old column should be cleared
        assert_nil @version.sbom
      end
      
      should 'return false if sbom is nil' do
        @version.sbom = nil
        
        assert_no_difference 'Sbom.count' do
          result = @version.migrate_sbom_to_table
          assert_not result
        end
      end
      
      should 'return false if sbom_record already exists' do
        @version.sbom = @sbom_data
        @version.save!
        @version.create_sbom_record!(data: @sbom_data)
        
        assert_no_difference 'Sbom.count' do
          result = @version.migrate_sbom_to_table
          assert_not result
        end
      end
      
      should 'handle errors gracefully' do
        @version.sbom = @sbom_data
        @version.save!
        
        # Force an error
        @version.stubs(:create_sbom_record!).raises(StandardError.new('Test error'))
        Rails.logger.expects(:error).with(includes('Test error'))
        
        assert_no_difference 'Sbom.count' do
          result = @version.migrate_sbom_to_table
          assert_not result
        end
      end
    end
    
    context '.sbom_migration_stats' do
      should 'return migration statistics' do
        # Count existing versions to account for any setup data
        initial_count = Version.count
        initial_with_sbom = Version.where.not(sbom: nil).count
        initial_migrated = Version.joins(:sbom_record).count
        
        Version.create!(package: @package, number: 'v1', sbom: {'test' => 'data'})
        Version.create!(package: @package, number: 'v2', sbom: {'test' => 'data'})
        Version.create!(package: @package, number: 'v3') # No SBOM
        
        # One already migrated
        v4 = Version.create!(package: @package, number: 'v4', sbom: {'test' => 'data'})
        v4.create_sbom_record!(data: {'test' => 'data'})
        
        stats = Version.sbom_migration_stats
        
        assert_equal initial_count + 4, stats[:total_versions]
        assert_equal initial_with_sbom + 3, stats[:total_with_sbom]
        assert_equal initial_migrated + 1, stats[:migrated]
        assert_equal 2, stats[:to_migrate]
        
        # Calculate expected percentage
        total_with_sbom = initial_with_sbom + 3
        migrated = initial_migrated + 1
        expected_percent = (migrated.to_f / total_with_sbom * 100).round(2)
        assert_equal expected_percent, stats[:progress_percent]
      end
    end
    
    # ==========================================
    # TODO: Remove all tests below after SBOM migration is complete
    # These test the dual-mode operation and migration functionality
    # ==========================================
    
    context 'dual-mode SBOM operation' do
      setup do
        @sbom_data = {
          'distro' => {
            'prettyName' => 'Alpine Linux v3.17'
          },
          'descriptor' => {
            'version' => 'v0.70.0'
          },
          'artifacts' => [
            {'purl' => 'pkg:npm/express@4.18.2'},
            {'purl' => 'pkg:npm/lodash@4.17.21'}
          ]
        }
      end
      
      context 'reading SBOM data' do
        context 'when only old structure exists' do
          setup do
            @version.sbom = @sbom_data
            @version.save!
          end
          
          should 'read distro from old structure' do
            assert_equal 'Alpine Linux v3.17', @version.distro
          end
          
          should 'read syft_version from old structure' do
            assert_equal 'v0.70.0', @version.syft_version
          end
          
          should 'return sbom data from old structure' do
            assert_equal @sbom_data, @version.sbom_data
          end
          
          should 'return true for has_sbom?' do
            assert @version.has_sbom?
          end
          
          should 'return purls from old structure' do
            expected_purls = ['pkg:npm/express@4.18.2', 'pkg:npm/lodash@4.17.21']
            assert_equal expected_purls, @version.purls
          end
        end
        
        context 'when only new structure exists' do
          setup do
            @version.update!(
              distro_name: 'Ubuntu 22.04',
              syft_version: 'v0.71.0',
              artifacts_count: 3
            )
            @version.create_sbom_record!(data: @sbom_data)
          end
          
          should 'read distro from cached field' do
            assert_equal 'Ubuntu 22.04', @version.distro
          end
          
          should 'read syft_version from cached field' do
            assert_equal 'v0.71.0', @version.syft_version
          end
          
          should 'return sbom data from new structure' do
            assert_equal @sbom_data, @version.sbom_data
          end
          
          should 'return true for has_sbom?' do
            assert @version.has_sbom?
          end
          
          should 'return purls from new structure' do
            expected_purls = ['pkg:npm/express@4.18.2', 'pkg:npm/lodash@4.17.21']
            assert_equal expected_purls, @version.purls
          end
        end
        
        context 'when both structures exist' do
          setup do
            # Create with old structure
            @version.sbom = @sbom_data
            @version.save!
            
            # Add new structure with different data
            @new_sbom_data = @sbom_data.dup
            @new_sbom_data['distro']['prettyName'] = 'Debian 11'
            @new_sbom_data['descriptor']['version'] = 'v0.72.0'
            
            @version.update!(
              distro_name: 'Debian 11',
              syft_version: 'v0.72.0',
              artifacts_count: 2
            )
            @version.create_sbom_record!(data: @new_sbom_data)
          end
          
          should 'prefer cached fields for distro' do
            assert_equal 'Debian 11', @version.distro
          end
          
          should 'prefer cached fields for syft_version' do
            assert_equal 'v0.72.0', @version.syft_version
          end
          
          should 'prefer new structure for sbom_data' do
            assert_equal @new_sbom_data, @version.sbom_data
          end
          
          should 'prefer new structure for purls' do
            expected_purls = ['pkg:npm/express@4.18.2', 'pkg:npm/lodash@4.17.21']
            assert_equal expected_purls, @version.purls
          end
        end
      end
      
      context '#parse_sbom dual-mode behavior' do
        setup do
          @version2 = Version.create!(package: @package, number: '4.0.0')
          @syft_output = @sbom_data.to_json
        end
        
        should 'create sbom_record and clear old column when successful' do
          status_mock = mock('status')
          status_mock.stubs(:success?).returns(true)
          Open3.expects(:capture2).with('syft', 'test/package:4.0.0', '--quiet', '--output', 'syft-json').returns([@syft_output, status_mock])
          
          assert_difference 'Sbom.count', 1 do
            @version2.parse_sbom
          end
          
          @version2.reload
          
          # Check old structure is cleared after successful new structure save
          assert_nil @version2.sbom
          
          # Check new structure
          assert_not_nil @version2.sbom_record
          assert_equal @sbom_data, @version2.sbom_record.data
          
          # Check cached fields
          assert_equal 'Alpine Linux v3.17', @version2.distro_name
          assert_equal 'v0.70.0', @version2.syft_version
          assert_equal 2, @version2.artifacts_count
          
          # Check sbom_record cached fields
          assert_equal 'Alpine Linux v3.17', @version2.sbom_record.distro_name
          assert_equal 'v0.70.0', @version2.sbom_record.syft_version
          assert_equal 2, @version2.sbom_record.artifacts_count
        end
        
        should 'update existing sbom_record and clear old column' do
          # Create initial sbom_record
          @version2.create_sbom_record!(data: { 'old' => 'data' })
          @version2.update!(sbom: { 'old' => 'sbom_data' }) # Has old data
          
          status_mock = mock('status')
          status_mock.stubs(:success?).returns(true)
          Open3.expects(:capture2).with('syft', 'test/package:4.0.0', '--quiet', '--output', 'syft-json').returns([@syft_output, status_mock])
          
          assert_no_difference 'Sbom.count' do
            @version2.parse_sbom
          end
          
          @version2.reload
          assert_equal @sbom_data, @version2.sbom_record.data
          assert_nil @version2.sbom # Should clear old column after successful update
        end
        
        should 'fall back to old column if sbom_record creation fails' do
          status_mock = mock('status')
          status_mock.stubs(:success?).returns(true)
          Open3.expects(:capture2).with('syft', 'test/package:4.0.0', '--quiet', '--output', 'syft-json').returns([@syft_output, status_mock])
          
          # Make sbom_record creation fail
          @version2.stubs(:create_sbom_record!).raises(StandardError.new('DB error'))
          Rails.logger.expects(:error).with(includes('Failed to save to sbom_record'))
          
          # Should still save the version with sbom data in old column
          @version2.parse_sbom
          @version2.reload
          
          assert_nil @version2.sbom_record
          assert_equal @sbom_data, @version2.sbom # Falls back to old column
          assert_equal 'Alpine Linux v3.17', @version2.distro_name
        end
      end
    end
  end
end
