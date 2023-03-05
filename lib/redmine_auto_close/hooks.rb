module RedmineAutoClose
  class Hooks < Redmine::Hook::ViewListener
    # 全ビューのベースHTMLを作成時
    def view_layouts_base_html_head(context = { })
        stylesheet_link_tag('auto_close.css', :plugin => 'redmine_auto_close')
    end

    # 新規チケットの保存前
    def controller_issues_new_before_save(context = {})
      parentStatusTransition(context)
    end

    # 既存チケットの保存前
    def controller_issues_edit_before_save(context = {})
      parentStatusTransition(context)
    end

    # チケット一覧の右クリックからの保存前
    def controller_issues_bulk_edit_before_save(context = {})
      parentStatusTransition(context)
    end

    def parentStatusTransition(context = {})
      Rails.logger.error "1"

      # 親チケットが設定されていないのであれば、何もしない。
      if context[:issue].parent_id.nil? 
        return
      end

      Rails.logger.error "2"

      # ステータスが変更になっていない場合は、何もしない。
      current_status_id = context[:issue].status_id_was
      next_status_id = context[:params][:issue][:status_id].to_i
      if current_status_id == next_status_id 
        return
      end

      Rails.logger.error "3"

      # ステータスが終了にならないのであれば、何もしない。
      next_status = IssueStatus.find_by(id: next_status_id)
      if !next_status.is_closed?
        return
      end

      Rails.logger.error "4"

      # 親チケットの全子チケットのステータスが、終了になっていないならば、何もしない。
      parent_issue = Issue.find_by_id(context[:issue].parent_id)
      parent_issue.descendants.visible.each do |child|
        if child.id != context[:issue].id then
          child_status = IssueStatus.find_by(id: child.status_id)
          if !child_status.is_closed?
            return
          end
        end
      end

      Rails.logger.error "5"

      # 一つも条件を満たさなければ、何もしない。
      project = context[:project].identifier if context[:project]
      items = AutoClose.all.order(:id).select {|item| isMatch?(project, parent_issue, item)}
      if items.empty?
        return
      end

      Rails.logger.error "6"

      item = items[0]
      # コメントが設定されていたら、コメントを設定する。
      if !item.action_comment.nil?
        journal = parent_issue.init_journal(User.current, item.action_comment)
        journal.save
      end

      Rails.logger.error "7"

      # ステータスが設定されていたら、ステータスを設定する。
      needUpdateflag = false
      if !item.action_status.nil?
        parent_issue.status_id = item.action_status
        needUpdateflag = true
      end

      Rails.logger.error "8"

      # 担当が設定されていたら、担当を設定する。
      if !item.action_assinged_to.nil?
        parent_issue.assinged_to = item.action_assinged_to
        needUpdateflag = true
      end
      if needUpdateflag 
        parent_issue.save
      end

      Rails.logger.error "9"

    end

    # トリガ対象となっているかを調べる
    def isMatch?(project, parent_issue, item)

      Rails.logger.error "a"

      # 有効になっているか？
      retrun false unless item.available?

      Rails.logger.error "b"

      # 子チケット終了になっているか？
      return false unless item.is_triger_child_closed?

      Rails.logger.error "c"

      # プロジェクトは対象になっているか？
      if item.project_pattern.present?
        return false unless project.present?
        return false unless project =~ Regexp.new(item.project_pattern)
      end

      Rails.logger.error "d"

      # トラッカーは、対象になっているか？
      tracker_id = parent_issue.tracker_id
      if item.trigger_tracker.present?
        return false unless item.trigger_tracker == tracker_id
      end

      Rails.logger.error "e"

      # ステータスは、対象になっているか？
      status_id = parent_issue.status_id
      if item.trigger_status.present?
        return false unless item.trigger_status == status_id
      end

      Rails.logger.error "f"

      # カスタムフィールドは、対象になっているか？
      # どうやって記述すればよい？
      return true
    end

  end
end