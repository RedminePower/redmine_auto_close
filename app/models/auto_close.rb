class AutoClose < ActiveRecord::Base
  validates_presence_of :title

  validate :valid_action

  TRIGGERS_CHILDREN_CLOSED = "children closed"
  TRIGGERS_EXPIRED = "expired"

  @@triggers = {
    :label_triggers_child_closed => TRIGGERS_CHILDREN_CLOSED,
    :label_triggers_expired => TRIGGERS_EXPIRED,
  }

  def triggers
    @@triggers
  end

  def is_triger_child_closed?
    trigger_type == TRIGGERS_CHILDREN_CLOSED
  end

  def is_triger_expired?
    trigger_type == TRIGGERS_EXPIRED
  end

  def available?
    is_enabled 
  end

  def valid_action
    
    #トリガ種類が、期限切れの場合
    if is_triger_expired?
      # アクションユーザーが設定されていなければいけない
      unless action_user.present?
        errors.add(:path_pattern, :invalid)
      end
    end

    # プロジェクトパターンが設定されていた場合
    if project_pattern.present?
      begin
        Regexp.compile(project_pattern)
      rescue
        errors.add(:project_pattern, :invalid)
      end
    end

    # アクションが一つも設定されていなかった場合
    if action_status.blank? && action_assinged_to.blank? && action_comment.blank?
      errors.add(:action_status, l(:error_set_one_or_more_actios))
      errors.add(:action_assinged_to, l(:error_set_one_or_more_actios))
      errors.add(:action_comment, l(:error_set_one_or_more_actios))
    end

  end

end
