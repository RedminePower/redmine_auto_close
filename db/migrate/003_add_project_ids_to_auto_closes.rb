# このファイルを修正後に適用するためには、以下のコマンドを実行する。
#--------------------
# cd C:\Bitnami\redmine-4.2.3-1\apps\redmine\htdocs\plugins\redmine_auto_close
# bundle exec rake redmine:plugins:migrate RAILS_ENV=production
#--------------------

class AddProjectIdsToAutoCloses < ActiveRecord::Migration[5.2]
  def up
    add_column :auto_closes, :project_ids, :text
  end
end
