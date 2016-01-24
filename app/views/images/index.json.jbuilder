json.array!(@images) do |image|
  json.extract! image, :id, :note_count, :post_url, :media_url, :posted_at, :published
  json.url image_url(image, format: :json)
end
