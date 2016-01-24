require 'json'
require 'open-uri'
require 'uri'

namespace :spider do
  desc "Updates ratings"
  task update_score: :environment do
    Image.all.each do |i|
      i.velocity = (i.note_count.to_f / (Time.now.utc - i.posted_at).to_f / 3600).to_f
      i.save
    end
  end
  desc "Crawls tumblr to save new images"
  task tumblr_import: :environment do
    def find_images(search_tag)
      api_key = ENV['TUMBLR_API_KEY']
      p search_tag
      unless Obscenity.profane?(search_tag)
        page = 0
        last_time = ''
        until page >= 40
          tumblr_api_key = "&api_key=#{api_key}"
          tag_url = 'https://api.tumblr.com/v2/tagged?tag='
          limit = '&limit=20'
          before = "&before=#{last_time}"
          tag = URI.escape(search_tag)

          url = tag_url + tag + tumblr_api_key + limit + before
          res = Faraday.get(url)
          if res.status.to_s == '200'
            buffer = open(url).read
            result = JSON.parse(buffer)
            results = result['response']
          else
            page = page + 1
            next
          end

          if !results.empty?
            last_time = results.last['timestamp'].to_i
            results.keep_if {|p| p['type'] == 'photo'}
            results.keep_if {|p| p['note_count'].to_i >= 3}

            results.each do |post|
              # p post['post_url']
              tag_text = String.new
              post['tags'].each {|t| tag_text << "#{t} "}
              sucks = Obscenity.offensive(tag_text)
              if sucks.count == 0 
                user_url = "https://api.tumblr.com/v2/blog/#{post['blog_name']}.tumblr.com/info?api_key=#{api_key}"
                res = Faraday.get(user_url)
                if res.status.to_s == '200'
                  buffer = open(user_url).read
                  user_json = JSON.parse(buffer)
                else
                  next
                end
                user = user_json['response']['blog']
                user_posts = user['posts'].to_i
                user_likes = user['likes'].to_i
                user_ratio = (user_likes.to_f / (user_posts.to_f + 1)).to_i

                if user_ratio >= 15
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
                  post['tags'].first(5).each do |t|
                    tag_name = t.to_s
                    if Obscenity.profane?(tag_name)
                    else
                      i.tag_list.add(tag_name)
                    end
                  end
                  p post['post_url']
                  i.save
                end
              end
            end
            page = page + 1
          end
        end
      end
    end

    top_tags = ActsAsTaggableOn::Tag.most_used(50).sample(10)
    seed = [
      'black and white photography',
      'nasa',
      'space',
      'architecture',
      'retro',
      'minimal',
      'design',
      'geometric',
      'abstract',
      'adventure'
    ]

    if top_tags.count < 10
      seed.each do |t|
        find_images(t)
      end
    else
      seed.each do |t|
        find_images(t)
      end
      top_tags.each do |t|
        find_images(t.name)
      end
    end
  end
end
