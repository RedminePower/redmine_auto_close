class AutoClose < ActiveRecord::Base
  validates_presence_of :title

  validate :valid_action

  TRIGGER_TYPES_CHILDREN_CLOSED = "children closed"
  TRIGGER_TYPES_EXPIRED = "expired"

  @@trigger_types = {
    :label_triggers_child_closed => TRIGGER_TYPES_CHILDREN_CLOSED,
    :label_triggers_expired => TRIGGER_TYPES_EXPIRED,
  }

  #------------------------------
  # トリガ種類（選択肢）
  #------------------------------
  def trigger_types
    @@trigger_types
  end

  #------------------------------
  # トリガ種類（ラベル）
  #------------------------------
  def trigger_type_label
    @@trigger_types.key(trigger_type)
  end

  #------------------------------
  # トラッカー（ラベル）
  #------------------------------
  def trigger_tracker_label
    if trigger_tracker.nil?
      ""
    else
      temp = Tracker.find_by(id: trigger_tracker)
      temp.nil? ? "" : temp.name
    end
  end

  #------------------------------
  # ステータス（ラベル）
  #------------------------------
  def trigger_status_label
    if trigger_status.nil?
      ""
    else
      temp = IssueStatus.find_by(id: trigger_status)
      temp.nil? ? "" : temp.name
    end
  end

  #------------------------------
  # カスタムフィールド（ラベル）
  #------------------------------
  def trigger_custom_field_label
    if trigger_custom_field.nil?
      ""
    else
      temp = CustomField.find_by(id: trigger_custom_field)
      temp.nil? ? "" : temp.name
    end
  end

  #------------------------------
  # トリガ カスタムフィールド （選択肢）
  #------------------------------
  def trigger_custom_fields
    CustomField.where(field_format: 'bool')
  end

  def is_triger_child_closed?
    trigger_type == TRIGGER_TYPES_CHILDREN_CLOSED
  end

  def is_triger_expired?
    trigger_type == TRIGGER_TYPES_EXPIRED
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
