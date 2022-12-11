class CreateAutoCloses < ActiveRecord::Migration[5.2]
  def change
    create_table :auto_closes do |t|
      t.text :title
      t.boolean :is_enabled, :default => true
      t.text :project_pattern
      t.text :trigger_type
      t.integer :trigger_tracker
      t.integer :trigger_status
      t.text :action_user
      t.integer :action_status
      t.integer :action_assinged_to
      t.text :action_comment
      t.boolean :is_action_comment_parent
    end
  end
end
