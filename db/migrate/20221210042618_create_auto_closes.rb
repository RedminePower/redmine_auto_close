# このファイルを修正後に適用するためには、以下のコマンドを実行する。
#--------------------
# cd C:\Bitnami\redmine-4.2.3-1\apps\redmine\htdocs\plugins\redmine_auto_close
# bundle exec rake redmine:plugins:migrate RAILS_ENV=production
#--------------------
class CreateAutoCloses < ActiveRecord::Migration[5.2]
  def change
    create_table :auto_closes do |t|
      t.text :title
      t.boolean :is_enabled, :default => true
      t.text :project_pattern
      t.text :trigger_type
      t.integer :trigger_tracker
      t.integer :trigger_status
      t.integer :trigger_custom_field
      t.boolean :trigger_custom_field_boolean, :default => true
      t.integer :action_user
      t.integer :action_status
      t.integer :action_assinged_to
      t.text :action_comment
      t.boolean :is_action_comment_parent
    end
  end
end
