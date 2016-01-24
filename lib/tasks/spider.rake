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
      p search_tag
      current_media_ids = Image.all.collect {|i| i.media_id.to_i}

      unless Obscenity.profane?(search_tag)
        url = 'https://api.tumblr.com/v2/'
        tumblr_api_key = ENV['TUMBLR_API_KEY']
    
        conn = Faraday.new(url: url) do |faraday|
          faraday.adapter Faraday.default_adapter
          faraday.response :json
        end

        page = 0
        page_limit = 20
        last_time = ''

        until page >= page_limit
          p page
          page = page + 1
          tag_response = conn.get('tagged', tag: search_tag, limit: '20', before: last_time, api_key: tumblr_api_key)
          if tag_response.status.to_s == '200'
            results = tag_response.body['response']

            # Set the before for the next page
            last_time = results.last['timestamp'].to_s

            # Check for duplicates
            new_media_ids = results.collect{|r| r['id'].to_i}
            if !(new_media_ids & current_media_ids).empty?
              page = page_limit
              next
            end

          # Start the next loop if the API call fails
          else
            next
          end

          # Make sure there's enough results before moving on
          if results.empty?
            page = page_limit
            next
          else
            results.keep_if {|p| p['type'] == 'photo'}
            results.keep_if {|p| p['note_count'].to_i >= 1}

            results.each do |post|
              # p post['post_url']
              tag_text = String.new
              post['tags'].each {|t| tag_text << "#{t} "}
              sucks = Obscenity.offensive(tag_text)
              if sucks.count == 0 
                user_response = conn.get("blog/#{post['blog_name']}.tumblr.com/info", api_key: tumblr_api_key)
                if user_response.status.to_s == '200'
                  user = user_response.body['response']['blog']
                else
                  next
                end
                user_posts = user['posts'].to_i
                user_likes = user['likes'].to_i
                user_ratio = (user_likes.to_f / (user_posts.to_f + 1)).to_i

                if user_ratio >= 10
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
      'lettering',
      'gifart',
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
