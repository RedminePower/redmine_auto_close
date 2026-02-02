# frozen_string_literal: true

class AutoClose < ActiveRecord::Base
  after_initialize :set_default_values
  validates_presence_of :title

  validate :valid_action

  serialize :project_ids, type: Array, coder: YAML

  def project_ids
    super.presence&.map(&:to_i) || []
  end

  def project_ids=(values)
    super(values.map(&:to_i))
  end

  # プロジェクトの設定方法を project_pattern から project_ids に切り替えたので
  # project_pattern での設定が残っていたら、それをもとに project_ids を設定する
  def migrate_project_pattern
    return if project_pattern.blank?

    p_ids = Project.all.select { |p| p.identifier =~ Regexp.new(project_pattern) }.map(&:id)
    Rails.logger.info "#{self.class} id=#{id} title=#{title} migrate project_pattern=#{project_pattern} -> project_ids=#{p_ids}"
    self.project_ids = p_ids
    self.project_pattern = nil
    save
  end

  def project_ids_label
    if project_ids.nil?
      ''
    else
      Project.where(id: project_ids).pluck(:name).join(', ')
    end
  end

  TRIGGER_TYPES_CHILDREN_CLOSED = 'children closed'
  TRIGGER_TYPES_EXPIRED = 'expired'

  TRIGGER_TYPES = {
    label_triggers_child_closed: TRIGGER_TYPES_CHILDREN_CLOSED,
    # label_triggers_expired: TRIGGER_TYPES_EXPIRED,
  }.freeze

  #------------------------------
  # トリガ種類（選択肢）
  #------------------------------
  def trigger_types
    TRIGGER_TYPES
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
      ''
    else
      temp = Tracker.find_by(id: trigger_tracker)
      temp.nil? ? '' : temp.name
    end
  end

  #------------------------------
  # ステータス（ラベル）
  #------------------------------
  def trigger_status_label
    if trigger_status.nil?
      ''
    else
      temp = IssueStatus.find_by(id: trigger_status)
      temp.nil? ? '' : temp.name
    end
  end

  #------------------------------
  # カスタムフィールド（ラベル）
  #------------------------------
  def trigger_custom_field_label
    if trigger_custom_field.nil?
      ''
    else
      temp = CustomField.find_by(id: trigger_custom_field)
      temp.nil? ? '' : temp.name
    end
  end

  #------------------------------
  # 真偽値型 カスタムフィールド （選択肢）
  #------------------------------
  def bool_custom_fields
    CustomField.where(field_format: 'bool')
  end

  #------------------------------
  # ユーザ型 カスタムフィールド （選択肢）
  #------------------------------
  def user_custom_fields
    CustomField.where(field_format: 'user')
  end

  def is_trigger_child_closed?
    trigger_type == TRIGGER_TYPES_CHILDREN_CLOSED
  end

  def is_trigger_expired?
    trigger_type == TRIGGER_TYPES_EXPIRED
  end

  def available?
    is_enabled
  end

  def valid_action
    # トリガ種類が、期限切れの場合
    # アクションユーザーが設定されていなければいけない
    if is_trigger_expired? && action_user.blank?
      errors.add(:action_user, :invalid)
    end

    # プロジェクトパターンが設定されていた場合
    if project_pattern.present?
      begin
        Regexp.compile(project_pattern)
      rescue StandardError
        errors.add(:project_pattern, :invalid)
      end
    end

    # トリガ題名パターンが設定されていた場合
    if trigger_subject_pattern.present?
      begin
        Regexp.compile(trigger_subject_pattern)
      rescue StandardError
        errors.add(:trigger_subject_pattern, :invalid)
      end
    end

    # アクションが一つも設定されていなかった場合
    return unless action_status.blank? && action_assigned_to.blank? && action_comment.blank?

    errors.add(:action_status, I18n.t(:error_set_one_or_more_actions))
    errors.add(:action_assigned_to, I18n.t(:error_set_one_or_more_actions))
    errors.add(:action_comment, I18n.t(:error_set_one_or_more_actions))
  end

  private

  def set_default_values
    self.trigger_type ||= TRIGGER_TYPES_CHILDREN_CLOSED
  end
end
