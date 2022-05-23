class CreateCanvasOauthAuthorizedUsers < ActiveRecord::Migration[4.2]
  def change
    create_table :canvas_oauth_authorized_users do |t|
      t.integer "user_id"
      t.integer "course_id"
      t.string  "user_roll"
      t.string  "feature_name"

      t.timestamps
    end
  end
end
