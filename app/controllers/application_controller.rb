class ApplicationController < ActionController::Base
  include Pagy::Backend

  skip_before_action :verify_authenticity_token

  after_action lambda {
    request.session_options[:skip] = true
  }

  def default_url_options(options = {})
    Rails.env.production? ? { :protocol => "https" }.merge(options) : options
  end

  def sanitize_sort(allowed_columns, default: 'updated_at')
    sort_param = params[:sort].presence || default
    sql = allowed_columns[sort_param] || allowed_columns[default] || default
    Arel.sql(sql)
  end
end
