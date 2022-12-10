class CreateAutoCloses < ActiveRecord::Migration[5.2]
  def change
    create_table :auto_closes do |t|
      t.integer :trigger
      t.string :target_project_pattern
      t.integer :target_tracker
      t.integer :target_status
      t.string :target_cf1_field
      t.string :target_cf1_value
      t.string :target_cf2_field
      t.string :target_cf2_value
      t.integer :action_user
      t.text :action_comment
      t.boolean :action_comment_parent
      t.integer :action_assingedTo
      t.integer :action_status
    end
  end
end
