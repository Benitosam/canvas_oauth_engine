class AddColumnRefreshTokenInAuthorizations < ActiveRecord::Migration[7.0]
  def change
    add_column :canvas_oauth_authorizations, :refresh_token, :text
  end
end
