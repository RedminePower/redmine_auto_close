# frozen_string_literal: true

class AutoClose < ActiveRecord::Base
  after_initialize :set_default_values
  validates_presence_of :title
  validates :max_issues_per_run, presence: true, numericality: { only_integer: true, greater_than: 0 }

  validate :valid_action

  # Rails 7.1+ では serialize の引数が変更された
  if Rails::VERSION::MAJOR >= 7 && Rails::VERSION::MINOR >= 1
    serialize :project_ids, type: Array, coder: YAML
  else
    serialize :project_ids, Array
  end

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
    if project_ids.empty?
      ''
    else
      Project.where(id: project_ids).pluck(:name).join(', ')
    end
  end

  TRIGGER_TYPES_CHILDREN_CLOSED = 'children closed'
  TRIGGER_TYPES_EXPIRED = 'expired'

  TRIGGER_TYPES = {
    label_triggers_child_closed: TRIGGER_TYPES_CHILDREN_CLOSED,
    label_triggers_expired: TRIGGER_TYPES_EXPIRED,
  }.freeze

  # action_user の特殊値
  ACTION_USER_ASSIGNEE = 'assignee'
  ACTION_USER_AUTHOR = 'author'
  ACTION_USER_PARENT_ASSIGNEE = 'parent_assignee'

  #------------------------------
  # トリガー種類（選択肢）
  #------------------------------
  def trigger_types
    TRIGGER_TYPES
  end

  #------------------------------
  # トリガー種類（ラベル）
  #------------------------------
  def trigger_type_label
    TRIGGER_TYPES.key(trigger_type)
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
  # ユーザー型 カスタムフィールド （選択肢）
  #------------------------------
  def user_custom_fields
    CustomField.where(field_format: 'user')
  end

  #------------------------------
  # 実行ユーザー（選択肢）
  #------------------------------
  def action_user_options
    special_options = [
      [I18n.t(:label_issue_assignee), ACTION_USER_ASSIGNEE],
      [I18n.t(:label_issue_author), ACTION_USER_AUTHOR],
      [I18n.t(:label_parent_assignee), ACTION_USER_PARENT_ASSIGNEE],
    ]
    user_options = User.where(status: 1).collect { |u| [u.name, u.id.to_s] }
    special_options + user_options
  end

  #------------------------------
  # 実行ユーザー（ラベル）
  #------------------------------
  def action_user_label
    case action_user
    when ACTION_USER_ASSIGNEE
      I18n.t(:label_issue_assignee)
    when ACTION_USER_AUTHOR
      I18n.t(:label_issue_author)
    when ACTION_USER_PARENT_ASSIGNEE
      I18n.t(:label_parent_assignee)
    else
      user = User.find_by(id: action_user)
      user&.name || ''
    end
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
    # トリガー種類が、期限切れの場合
    # アクションユーザーが設定されていなければいけない
    if is_trigger_expired? && action_user.blank?
      errors.add(:action_user, :invalid)
    end

    # トリガー種類が、期限切れの場合
    # 少なくとも1つの条件が設定されていなければいけない
    if is_trigger_expired?
      has_condition = (project_ids.present? && project_ids.any?) ||
                      trigger_tracker.present? ||
                      trigger_subject_pattern.present? ||
                      trigger_status.present? ||
                      trigger_custom_field.present?
      unless has_condition
        errors.add(:base, I18n.t(:error_expired_requires_condition))
      end
    end

    # プロジェクトパターンが設定されていた場合
    if project_pattern.present?
      begin
        Regexp.compile(project_pattern)
      rescue StandardError
        errors.add(:project_pattern, :invalid)
      end
    end

    # トリガー題名パターンが設定されていた場合
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
    self.action_user ||= ACTION_USER_ASSIGNEE
    self.max_issues_per_run ||= 50
  end
end
