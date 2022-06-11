class AddColumnExpiresInAuthorization < ActiveRecord::Migration[4.2]
  def change
    add_column :canvas_oauth_authorizations, :expires_in, :text
  end
end
