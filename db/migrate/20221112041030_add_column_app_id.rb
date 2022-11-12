class AddColumnAppId < ActiveRecord::Migration[4.2]
  def change
    add_column :canvas_oauth_authorizations, :app_id, :integer
    add_column :canvas_oauth_authorized_users, :app_id, :integer
  end
end
