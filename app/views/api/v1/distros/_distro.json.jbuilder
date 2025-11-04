json.extract! distro, :id, :pretty_name, :name, :id_field, :id_like, :version_id, :version_codename, :variant, :variant_id, :slug, :versions_count, :home_url, :support_url, :bug_report_url, :documentation_url, :logo, :ansi_color, :cpe_name, :build_id, :image_id, :image_version, :created_at, :updated_at
json.url api_v1_distro_url(distro.slug, format: :json)
json.html_url distro_url(distro.slug)
