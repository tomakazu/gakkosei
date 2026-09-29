class CreateVideos < ActiveRecord::Migration[7.1]
  def change
    create_table :videos do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.integer :status
      t.string :s3_raw_key
      t.integer :duration_seconds
      t.string :thumbnail_url
      t.string :manifest_url
      t.integer :visibility
      t.integer :view_count

      t.timestamps
    end
  end
end
