# frozen_string_literal: true

class AddExpiredTriggerSupport < ActiveRecord::Migration[5.2]
  def change
    # action_user を integer から string に変更（特殊値対応）
    change_column :auto_closes, :action_user, :string

    # 期限切れトリガー用の閾値カラムを追加
    add_column :auto_closes, :max_issues_per_run, :integer, default: 50
  end
end
