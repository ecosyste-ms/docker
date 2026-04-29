xml.instruct! :xml, version: '1.0', encoding: 'UTF-8'
xml.feed xmlns: 'http://www.w3.org/2005/Atom' do
  xml.title 'Docker Images'
  xml.subtitle 'Latest Docker images indexed by ecosyste.ms'
  xml.id packages_url
  xml.link href: packages_url
  xml.link href: packages_url(format: :atom), rel: 'self', type: 'application/atom+xml'
  xml.updated((@packages.first&.last_synced_at || Time.current).iso8601)

  @packages.each do |package|
    xml.entry do
      xml.title package.name
      xml.id package_url(package)
      xml.link href: package_url(package)
      xml.updated((package.last_synced_at || package.updated_at || Time.current).iso8601)
      xml.summary package.description if package.description.present?
    end
  end
end
