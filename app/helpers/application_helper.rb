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
    when 'packagist'
      'packagist.org'
    when 'cocoapods'
      'cocoapods.org'
    when 'clojars' 
      'clojars.org'
    when 'alpine'
      'alpine-v3.13'
    else
      'pkg_type'
    end 
  end

  def meta_title
    [@meta_title, 'Ecosyste.ms: Docker'].compact.join(' | ')
  end

  def meta_description
    @meta_description || 'An open API service providing dependency metadata for docker projects.'
  end
end
