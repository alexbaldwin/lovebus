require 'json'
require 'open-uri'
require 'uri'

namespace :spider do
  desc "Crawls tumblr to save new images"
  task tumblr_import: :environment do
    def find_images(search_tag)
      page = 0
      until page >= 5
        tumblr_api_key = '&api_key=***REMOVED***'
        tag_url = 'https://api.tumblr.com/v2/tagged?tag='
        offset = "&offset=#{page * 20}"
        limit = '&limit=20'
        tag = URI.escape(search_tag)

        url = tag_url + tag + tumblr_api_key + offset + limit
        p url
        buffer = open(url).read
        result = JSON.parse(buffer)

        results = result['response']
        results.keep_if {|p| p['type'] == 'photo'}
        results.keep_if {|p| p['note_count'].to_i >= 1}

        results.each do |post|
          posted_at = DateTime.parse(post['date'].to_s)
          note_count = post['note_count'].to_i
          velocity = (note_count.to_f / (Time.now.utc - posted_at).to_f / 3600).to_f
          i = Image.new(
            :note_count => note_count,
            :media_id => post['id'].to_s,
            :post_url => post['post_url'].to_s,
            :blog_name => post['blog_name'].to_s,
            :media_url => post['photos'][0]['original_size']['url'].to_s,
            :posted_at => posted_at,
            :velocity => velocity
          )
          post['tags'].each do |t|
            i.tag_list.add(t.to_s)
          end
          i.save
        end
        page = page + 1
      end
    end

    top_tags = ActsAsTaggableOn::Tag.most_used(10)
    if top_tags.count == 10
      top_tags.each do |t|
        find_images(t.name)
      end
    else
      find_images('black and white photography')
    end

  end
end
