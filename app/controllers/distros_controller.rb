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

    # Sort each group's distros by total_downloads (descending)
    @distro_groups.each do |key, group_distros|
      @distro_groups[key] = group_distros.sort_by do |d|
        -(d.total_downloads || 0)
      end
    end

    # Sort groups by total versions_count (sum of all distros in the group)
    @distro_groups = @distro_groups.sort_by { |_key, group_distros| -group_distros.sum(&:versions_count) }.to_h

    # Group discontinued distros separately
    @discontinued_groups = discontinued_distros.group_by(&:grouping_key).compact

    # Sort discontinued groups by total_downloads (descending)
    @discontinued_groups.each do |key, group_distros|
      @discontinued_groups[key] = group_distros.sort_by do |d|
        -(d.total_downloads || 0)
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
