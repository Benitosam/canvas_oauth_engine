class ChangeExpiresInType < ActiveRecord::Migration[4.2]
  def change
    remove_column :canvas_oauth_authorizations, :expires_in
    add_column :canvas_oauth_authorizations, :expires_at, :datetime
  end
end
