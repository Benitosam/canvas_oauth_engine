class ChangeExpiresInType < ActiveRecord::Migration[4.2]
  def change
    change_column :canvas_oauth_authorizations, :expires_in, :datetime, using: 'expires_in::timestamp without time zone'
  end
end