class CreateImages < ActiveRecord::Migration
  def change
    create_table :images do |t|
      t.integer :note_count
      t.string :blog_name
      t.string :media_id, uniqueness: true
      t.string :post_url
      t.string :media_url
      t.timestamp :posted_at
      t.boolean :published, null: false, default: false

      t.timestamps null: false
    end
  end
end
