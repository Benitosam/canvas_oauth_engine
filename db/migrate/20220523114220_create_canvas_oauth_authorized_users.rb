class CreateCanvasOauthAuthorizedUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :canvas_oauth_authorized_users do |t|

      t.timestamps
    end
  end
end
