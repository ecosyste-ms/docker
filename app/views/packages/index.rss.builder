xml.instruct! :xml, version: '1.0', encoding: 'UTF-8'
xml.rss version: '2.0' do
  xml.channel do
    xml.title 'Docker Images'
    xml.description 'Latest Docker images indexed by ecosyste.ms'
    xml.link packages_url
    xml.language 'en'

    @packages.each do |package|
      xml.item do
        xml.title package.name
        xml.description package.description if package.description.present?
        xml.link package_url(package)
        xml.guid package_url(package), isPermaLink: true
        xml.pubDate package.last_synced_at.rfc2822 if package.last_synced_at.present?
      end
    end
  end
end
