class Image < ActiveRecord::Base
  acts_as_taggable
  validates :media_id, uniqueness: true

  def score(i)
    p = i.note_count
    t = (Time.now.utc - i.posted_at).to_i / 60 / 60
    return (p - 1) / (t + 2)**0.8
  end
end
