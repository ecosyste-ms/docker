require "test_helper"

class SbomTest < ActiveSupport::TestCase
  context 'associations' do
    should belong_to(:version)
  end

  context 'validations' do
    should validate_presence_of(:data)
  end
  
  context 'uniqueness validation' do
    setup do
      @package = Package.create!(name: 'test/package')
      @version = Version.create!(package: @package, number: '1.0.0')
      @sbom = Sbom.create!(version: @version, data: { 'test' => 'data' })
    end
    
    should 'validate uniqueness of version_id' do
      duplicate = Sbom.new(version: @version, data: { 'other' => 'data' })
      assert_not duplicate.valid?
      assert_includes duplicate.errors[:version_id], 'has already been taken'
    end
  end
  
  context 'instance methods' do
    setup do
      @package = Package.create!(name: 'test/package')
      @version = Version.create!(package: @package, number: '1.0.0')
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
      @sbom = Sbom.new(version: @version, data: @sbom_data)
    end
    
    context '#distro' do
      should 'return distro prettyName from data' do
        assert_equal 'Ubuntu 20.04.5 LTS', @sbom.distro
      end
      
      should 'return nil if distro is missing' do
        @sbom.data = {}
        assert_nil @sbom.distro
      end
    end
    
    context '#descriptor_version' do
      should 'return descriptor version from data' do
        assert_equal 'v0.70.0', @sbom.descriptor_version
      end
      
      should 'return nil if descriptor is missing' do
        @sbom.data = {}
        assert_nil @sbom.descriptor_version
      end
    end
    
    context '#artifacts' do
      should 'return artifacts array from data' do
        assert_equal 4, @sbom.artifacts.count
        assert_equal 'express', @sbom.artifacts.first['name']
      end
      
      should 'return empty array if artifacts is missing' do
        @sbom.data = {}
        assert_equal [], @sbom.artifacts
      end
    end
    
    context '#purls' do
      should 'return unique sorted purls without blanks' do
        expected_purls = [
          'pkg:npm/express@4.18.2',
          'pkg:npm/lodash@4.17.21'
        ]
        assert_equal expected_purls, @sbom.purls
      end
      
      should 'return empty array if no artifacts' do
        @sbom.data = {}
        assert_equal [], @sbom.purls
      end
    end
    
    context 'before_save callback' do
      should 'cache fields before saving' do
        @sbom.save!
        
        assert_equal 'Ubuntu 20.04.5 LTS', @sbom.distro_name
        assert_equal 'v0.70.0', @sbom.syft_version
        assert_equal 2, @sbom.artifacts_count
      end
      
      should 'handle nil values gracefully' do
        @sbom.data = { 'artifacts' => [] }
        @sbom.save!
        
        assert_nil @sbom.distro_name
        assert_nil @sbom.syft_version
        assert_equal 0, @sbom.artifacts_count
      end
    end
  end
end