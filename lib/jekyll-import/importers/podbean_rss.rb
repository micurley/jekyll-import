require 'rss/nokogiri'

module JekyllImport
  module Importers
    class PodBeanRSS < Importer
      def self.specify_options(c)
        c.option 'source', '--source NAME', 'The RSS file or URL to import'
      end

      def self.validate(options)
        if options['source'].nil?
          abort "Missing mandatory option --source."
        end
      end

      def self.require_deps
        JekyllImport.require_with_fallback(%w[
          rss/1.0
          rss/2.0
          open-uri
          fileutils
          safe_yaml
        ])
      end

      # Process the import.
      #
      # source - a URL or a local file String.
      #
      # Returns nothing.
      def self.process(options)
        source = options.fetch('source')

        STDOUT.write "Processing #{source}"

        content = ""
        open(source) { |s| content = s.read }
        rss = ::RSS::Parser.parse(content, false)

        raise "There doesn't appear to be any RSS items at the source (#{source}) provided." unless rss

        # Channel Data
        STDOUT.write "Channel #{rss.channel}"
        title = rss.channel.title
        description = rss.channel.title
        category = rss.channel['itunes:category']
        subtitle = rss.channel.itunes_subtitle
        image = rss.channel.image.url
        image_width = rss.channel.image.width
        image_height = rss.channel.image.height

        rss.items.each do |item|
          formatted_date = item.date.strftime('%Y-%m-%d')
          post_name = item.title.split(%r{ |!|/|:|&|-|$|,}).map do |i|
            i.downcase if i != ''
          end.compact.join('-')
          name = "#{formatted_date}-#{post_name}"

          image = {
            'url' => image,
            'width' => image_width,
            'height' => image_height,
          }

          podcast = {
            'url'   => item.enclosure['url'],
            'length'    => {
                'seconds'   => item.enclosure['length'],
                'string'    => item.itunes_duration,
            },
            'type'  => item.enclosure['type'],
            'image'     => {
                'url'   => item.media_content['url'],
                'type'  => item.media_content['medium'],
            }
          }

          header = {
            'layout'        => 'post',
            'title'         => item.title,
            'description'   => description,
            'subtitle'      => subtitle,
            'category'      => [category, title],
            'image'         => image,
            'podcast'       => podcast,
          }

          FileUtils.mkdir_p("_posts")

          STDOUT.write 'Hello, World!'

          File.open("_posts/#{name}.html", "w") do |f|
            f.puts header.to_yaml
            f.puts "---\n\n"
            f.puts item.itunes_summary
          end
        end
      end
    end
  end
end
