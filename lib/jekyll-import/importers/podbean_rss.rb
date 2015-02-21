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

        STDOUT.write "Processing #{source}\n"

        content = ""
        open(source) { |s| content = s.read }
        content = content.gsub! '<media:content', '<image'
        content = content.gsub! '</media:content>', '</image>'

        rss = ::RSS::Parser.parse(content, false)

        raise "There doesn't appear to be any RSS items at the source (#{source}) provided." unless rss

        # Channel Data
        title = rss.channel.title
        directory = title.downcase.gsub(/[^\w-]+/, '-')

        STDOUT.write "Title: #{title}\n"

        subtitle = rss.channel.itunes_subtitle
        STDOUT.write "Subtitle: #{subtitle}\n"

        description = rss.channel.description
        STDOUT.write "Description: #{description}\n"

        category = rss.channel.category
        STDOUT.write "Category: #{category}\n"

        image = rss.channel.image.url
        image_width = rss.channel.image.width
        image_height = rss.channel.image.height
        STDOUT.write "Image: #{image}[#{image_width}x#{image_height}]\n"

        show_image = {
          'url' => image,
          'width' => image_width,
          'height' => image_height,
        }

        rss.items.each do |item|
          STDOUT.write "Item: #{item}\n\n\n"
          formatted_date = item.date.strftime('%Y-%m-%d')
          #post_name = item.title.split(%r{ |!|/|:|&|-|$|,}).map do |i|
          #  i.downcase if i != ''
          #end.compact.join('-')
          post_name = item.title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]+/, '')
          name = "#{formatted_date}-#{post_name}"

          podcast = {
            'url'   => item.enclosure.url,
            'length'    => {
                'seconds'   => item.enclosure.length,
                'string'    => item.itunes_duration.content,
            },
            'type'  => item.enclosure.type,
          }

            image = {
#                'url'   => item.image.url,
#                'type'  => item.image.medium,
            }

          header = {
            'layout'        => 'post',
            'title'         => item.title,
            'description'   => description,
            'subtitle'      => subtitle,
            'category'      => [category.content, title],
            'show_image'    => show_image,
            'image'         => image,
            'podcast'       => podcast,
          }

          FileUtils.mkdir_p("_posts/#{directory}")

          File.open("_posts/#{directory}/#{name}.html", "w") do |f|
            f.puts header.to_yaml
            f.puts "---\n\n"
            f.puts item.itunes_summary
          end
        end
      end
    end
  end
end
