class AddTweetToImages < ActiveRecord::Migration
  def change
    add_column :images, :tweet, :jsonb, null: false, default: '{}'
  end
end
