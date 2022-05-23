class AddColumnsCourseIdAndEnrollTypeToCanvasOauthAuthorizations < ActiveRecord::Migration[4.2]
  def change
    add_column :canvas_oauth_authorizations, :course_id, :integer
    add_column :canvas_oauth_authorizations, :enrollment_type, :string
  end
end
