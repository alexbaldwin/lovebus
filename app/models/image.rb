class Image < ActiveRecord::Base
  acts_as_taggable
  validates :media_id, uniqueness: true
end
