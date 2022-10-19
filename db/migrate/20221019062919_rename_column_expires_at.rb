class RenameColumnExpiresAt < ActiveRecord::Migration[4.2]
  def change
    rename_column :canvas_oauth_authorizations, :expires_at, :expires_in
  end
end
