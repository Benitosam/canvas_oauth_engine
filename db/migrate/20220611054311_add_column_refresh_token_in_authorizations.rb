class AddColumnRefreshTokenInAuthorizations < ActiveRecord::Migration[4.2]
  def change
    add_column :canvas_oauth_authorizations, :refresh_token, :text
  end
end
