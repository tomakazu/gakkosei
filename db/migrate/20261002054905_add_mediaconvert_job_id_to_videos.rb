class AddMediaconvertJobIdToVideos < ActiveRecord::Migration[7.1]
  def change
    add_column :videos, :mediaconvert_job_id, :string
  end
end
