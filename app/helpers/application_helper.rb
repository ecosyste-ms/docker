module ApplicationHelper
  include Pagy::Frontend
  
  def pkg_type_to_host(pkg_type)
    case pkg_type
    when 'maven'
      'repo1.maven.org'
    when 'gem'
      'rubygems.org'
    when 'npm'
      'npmjs.org'
    when 'pypi'
      'pypi.org'
    when 'nuget'
      'nuget.org'
    when 'cran'
      'cran.r-project.org'
    when 'composer'
      'packagist.org'
    when 'cocoapods'
      'cocoapods.org'
    when 'clojars' 
      'clojars.org'
    when 'alpine'
      'alpine-v3.13'
    when 'golang'
      'proxy.golang.org'
    when 'cargo'
      'crates.io'
    when 'pub'
      'pub.dev'
    when 'github'
      'github actions'
    when 'dart'
      'pub.dev'
    else
      pkg_type
    end 
  end

  def meta_title
    [@meta_title, 'Ecosyste.ms: Docker'].compact.join(' | ')
  end

  def meta_description
    @meta_description || app_description
  end

  def app_name
    "Docker"
  end

  def app_description
    'An open API service providing dependency metadata for docker images.'
  end

  def bootstrap_icon(symbol, options = {})
    return "" if symbol.nil?
    icon = BootstrapIcons::BootstrapIcon.new(symbol, options)
    content_tag(:svg, icon.path.html_safe, icon.options)
  end
end
