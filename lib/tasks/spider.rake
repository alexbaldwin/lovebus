require 'open-uri'

namespace :spider do
  desc "Find the good eggs"
  task smart_users: :environment do
    images = Image.where(published: true)
    hot_users = Array.new
    images.each do |image|
      score = 0
      if image.tweet?
        score += image.tweet['retweet_count'] * 10
        score += image.tweet['favorite_count'] * 1
      end
      hot_user = {}
      hot_user['username'] = image.blog_name
      hot_user['score'] = score
      hot_users << hot_user
    end
    hot_users.delete_if {|h| h['score'] == 0}
    hot_users.delete_if {|h| Obscenity.profane?(h['username'])}
    hot_users.sort_by! {|h| -h['score']}
    p hot_users
        url = 'https://api.tumblr.com/v2/'
        tumblr_api_key = ENV['TUMBLR_API_KEY']
    
        conn = Faraday.new(url: url) do |faraday|
          faraday.adapter Faraday.default_adapter
          faraday.response :json
        end

        # api.tumblr.com/v2/blog/{blog-identifier}/posts[/type]?api_key={key}&[optional-params=]
        hot_users.each do |h|
          user_response = conn.get("blog/#{h['username']}.tumblr.com/posts/photo", api_key: tumblr_api_key)
          if user_response.status.to_s == '200'
            posts = user_response.body['response']['posts']
          else
            next
          end
          posts.each do |post|
                  posted_at = DateTime.parse(post['date'].to_s)
                  note_count = post['note_count'].to_i
                  i = Image.new(
                    :note_count => note_count,
                    :media_id => post['id'].to_s,
                    :post_url => post['post_url'].to_s,
                    :blog_name => post['blog_name'].to_s,
                    :media_url => post['photos'][0]['original_size']['url'].to_s,
                    :posted_at => posted_at,
                    :velocity => 0
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
  desc "Get feedback from twitter"
  task get_smart: :environment do
    client = Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV['TWITTER_CLIENT'] 
      config.consumer_secret     = ENV['TWITTER_CLIENT_SECRET'] 
      config.access_token        = ENV['TWITTER_AUTH'] 
      config.access_token_secret = ENV['TWITTER_AUTH_SECRET'] 
    end

    images = Image.where(published: true).where(["created_at < ?", 1.days.ago])
    images.each do |image|
      id = image.tweet['id']
      if id
        tweet = client.status(id).to_json
        image.tweet = tweet.to_json
        image.save
      end
    end
  end
  desc "Tweet"
  task tweet: :environment do
    image = Image.where(published: false).order(velocity: :desc).first
    image.published = true
    image.save

    client = Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV['TWITTER_CLIENT'] 
      config.consumer_secret     = ENV['TWITTER_CLIENT_SECRET'] 
      config.access_token        = ENV['TWITTER_AUTH'] 
      config.access_token_secret = ENV['TWITTER_AUTH_SECRET'] 
    end

    tweet = client.update_with_media('', open(image.media_url))
    p tweet
    image.tweet = tweet.to_json
    image.save
  end
  desc "Grab results from Google Vision"
  task vision: :environment do
    vision_key = ""
    i = Image.last
    p i.media_url
    require 'base64'
    base_image = Base64.encode64(open(i.media_url) { |io| io.read })

    json_call =
    {
      "requests":[
        {
          "image":{
            "content": base_image.split("\n").join.split(" ").join
          },
          "features":[
            {
              "type":"LABEL_DETECTION",
              "maxResults":1
            }
          ]
        }
      ]
    }.to_json

    conn = Faraday.new(url: "https://vision.googleapis.com") do |faraday|
      faraday.adapter Faraday.default_adapter
      faraday.response :json
    end

    response = conn.post do |req|
      req.url "/v1/images:annotate?key=#{vision_key}"
      req.headers['Content-Type'] = 'application/json'
      req.body = json_call
    end
   
    p response
  end
  desc "Updates ratings"
  task update_score: :environment do
    Image.all.each do |i|
      i.velocity = i.score(i)
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
        page_limit = ENV['TUMBLR_PAGE_LIMIT'].to_i
        last_time = ''

        until page >= page_limit
          p page
          page = page + 1
          tag_response = conn.get('tagged', tag: search_tag, limit: '20', before: last_time, api_key: tumblr_api_key)
          if tag_response.status.to_s == '200'
            results = tag_response.body['response']


          # Kill the subject if the API call fails
          else
            page = page_limit
            next
          end

          # Make sure there's enough results before moving on
          if results.empty?
            page = page_limit
            next
          else
            # Check for duplicates
            new_media_ids = results.collect{|r| r['id'].to_i}
            if !(new_media_ids & current_media_ids).empty?
              page = page_limit
              next
            end

            # Set the before for the next page
            last_time = results.last['timestamp'].to_s

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
                  i = Image.new(
                    :note_count => note_count,
                    :media_id => post['id'].to_s,
                    :post_url => post['post_url'].to_s,
                    :blog_name => post['blog_name'].to_s,
                    :media_url => post['photos'][0]['original_size']['url'].to_s,
                    :posted_at => posted_at,
                    :velocity => 0
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

    seed = [
      'black and white photography',
      'nasa',
      'space',
      'architecture',
      'minimal',
      'geometric',
      'abstract'
    ]

    seed.each do |t|
      find_images(t)
    end

    # Too many problems with the randoms
    # top_tags = ActsAsTaggableOn::Tag.most_used(100).sample(20)
    # if top_tags.count < 10
    #   seed.each do |t|
    #     find_images(t)
    #   end
    # else
    #   seed.each do |t|
    #     find_images(t)
    #   end
    #   top_tags.each do |t|
    #     find_images(t.name)
    #   end
    # end

    Rake::Task["spider:update_score"].execute
  end
end
