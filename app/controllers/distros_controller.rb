class DistrosController < ApplicationController
  def index
    scope = Distro.all

    if params[:query].present?
      query = "%#{params[:query].downcase}%"
      scope = scope.where('LOWER(pretty_name) LIKE ? OR LOWER(name) LIKE ? OR LOWER(id_field) LIKE ?', query, query, query)
    end

    # Group by grouping_key (smart grouping that separates derivative distros)
    distros = scope.to_a
    @distro_groups = distros.group_by(&:grouping_key).compact

    # Sort each group's distros by version_id
    @distro_groups.each do |key, group_distros|
      @distro_groups[key] = group_distros.sort_by do |d|
        version_numeric = d.version_id.to_s.gsub(/[^\d.]/, '').to_f
        [version_numeric != 0 ? 0 : 1, -version_numeric, d.pretty_name]
      end
    end

    # Sort groups by total versions_count (sum of all distros in the group)
    @distro_groups = @distro_groups.sort_by { |_key, group_distros| -group_distros.sum(&:versions_count) }.to_h

    # Handle any distros without a grouping key
    @ungrouped_distros = distros.select { |d| d.grouping_key.nil? }
  end

  def show
    @distro = Distro.find_by_slug(params[:id])
    raise ActiveRecord::RecordNotFound unless @distro
    fresh_when(@distro, public: true)
  end
end
