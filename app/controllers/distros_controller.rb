class DistrosController < ApplicationController
  def index
    scope = Distro.all

    if params[:query].present?
      query = "%#{params[:query].downcase}%"
      scope = scope.where('LOWER(pretty_name) LIKE ? OR LOWER(name) LIKE ? OR LOWER(id_field) LIKE ?', query, query, query)
    end

    # Separate active and discontinued distros
    active_distros = scope.where(discontinued: false).to_a
    discontinued_distros = scope.where(discontinued: true).to_a

    # Group active distros by grouping_key
    @distro_groups = active_distros.group_by(&:grouping_key).compact

    # Deduplicate distros with same pretty_name, keeping the one with highest version_id
    # Then sort by total_downloads (descending), then by version_id (descending)
    @distro_groups.each do |key, group_distros|
      # Group by pretty_name and keep only the highest version_id for each
      deduped = group_distros.group_by(&:pretty_name).map do |_pretty_name, distros|
        distros.max_by { |d| d.version_id.to_s.split('.').map(&:to_i) }
      end

      @distro_groups[key] = deduped.sort_by do |d|
        version_numeric = d.version_id.to_s.gsub(/[^\d.]/, '').to_f
        [-(d.total_downloads || 0), version_numeric != 0 ? 0 : 1, -version_numeric, d.pretty_name]
      end
    end

    # Sort groups by total versions_count (sum of all distros in the group)
    @distro_groups = @distro_groups.sort_by { |_key, group_distros| -group_distros.sum(&:versions_count) }.to_h

    # Group discontinued distros separately
    @discontinued_groups = discontinued_distros.group_by(&:grouping_key).compact

    # Deduplicate distros with same pretty_name, keeping the one with highest version_id
    # Then sort by total_downloads (descending), then by version_id (descending)
    @discontinued_groups.each do |key, group_distros|
      # Group by pretty_name and keep only the highest version_id for each
      deduped = group_distros.group_by(&:pretty_name).map do |_pretty_name, distros|
        distros.max_by { |d| d.version_id.to_s.split('.').map(&:to_i) }
      end

      @discontinued_groups[key] = deduped.sort_by do |d|
        version_numeric = d.version_id.to_s.gsub(/[^\d.]/, '').to_f
        [-(d.total_downloads || 0), version_numeric != 0 ? 0 : 1, -version_numeric, d.pretty_name]
      end
    end

    @discontinued_groups = @discontinued_groups.sort_by { |_key, group_distros| -group_distros.sum(&:versions_count) }.to_h

    # Handle any distros without a grouping key (active only)
    @ungrouped_distros = active_distros.select { |d| d.grouping_key.nil? }
  end

  def show
    @distro = Distro.find_by_slug(params[:id])
    raise ActiveRecord::RecordNotFound unless @distro
    fresh_when(@distro, public: true)
  end
end
