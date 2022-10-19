class RenameColumnExpiresAt < ActiveRecord::Migration[7.0]
  def change
    rename_column :canvas_oauth_authorizations, :expires_at, :expires_in
  end
end
