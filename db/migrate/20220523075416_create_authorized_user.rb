class CreateAuthorizedUser < ActiveRecord::Migration[7.0]
  def change
    create_table :authorized_users do |t|
      t.integer  "user_id"
      t.string   "enrollment_type"
      t.integer  "course_id"
      t.string   "feature"
      
      t.timestamps
    end
  end
end
