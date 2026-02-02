# frozen_string_literal: true

module RedmineAutoClose
  class AutoCloseService
    # Check if an auto_close rule matches the given issue
    def self.matches?(project, parent_issue, item)
      # Check if enabled
      return false unless item.available?

      # Check trigger type (must be children closed)
      return false unless item.is_trigger_child_closed?

      # Check project pattern (legacy support)
      if item.project_pattern.present?
        return false if project.blank?
        return false unless project.identifier =~ Regexp.new(item.project_pattern)
      end

      # Check project_ids
      if item.project_ids.present? && item.project_ids.any?
        return false if project.blank?
        return false unless item.project_ids.any? { |id| project.id == id }
      end

      # Check tracker
      if item.trigger_tracker.present? && item.trigger_tracker != parent_issue.tracker_id
        return false
      end

      # Check subject pattern
      if item.trigger_subject_pattern.present? && parent_issue.subject !~ Regexp.new(item.trigger_subject_pattern)
        return false
      end

      # Check status
      if item.trigger_status.present? && item.trigger_status != parent_issue.status_id
        return false
      end

      # Check custom field
      if item.trigger_custom_field.present?
        cf_value = parent_issue.custom_field_values.detect { |v|
          v.custom_field_id == item.trigger_custom_field
        }
        if cf_value.present?
          # Redmine stores boolean custom field values as '1' (true) or '0' (false) in text column
          cf_value_to_bool = (cf_value.value == '1')
          return false if cf_value_to_bool != item.trigger_custom_field_boolean
        end
      end

      true
    end

    # Apply an auto_close rule to an issue
    def self.apply_rule(rule, issue)
      # Determine what changes to apply
      new_status_id = rule.action_status if rule.action_status.present?

      new_assigned_to_id = if rule.action_assigned_to.present?
                             rule.action_assigned_to
                           elsif rule.action_assigned_to_custom_field.present?
                             cf_value = issue.custom_field_values.detect { |v|
                               v.custom_field_id == rule.action_assigned_to_custom_field
                             }
                             cf_value.value if cf_value.present?
                           end

      needs_update = new_status_id.present? || new_assigned_to_id.present?

      # Save issue changes first if needed with retry on stale object
      if needs_update
        retries = 0
        begin
          issue.reload # Always reload to get latest version
          issue.status_id = new_status_id if new_status_id.present?
          issue.assigned_to_id = new_assigned_to_id if new_assigned_to_id.present?
          issue.save
        rescue ActiveRecord::StaleObjectError
          raise if retries >= 2

          retries += 1
          retry
        end
      end

      # Add comment after saving (to avoid lock version conflicts)
      return if rule.action_comment.blank?

      # 自動クローズ対象のチケットにコメント追加
      issue.reload
      journal = issue.init_journal(User.current, rule.action_comment)
      journal.save

      # 親チケット（祖父）にもコメント追加
      if rule.is_action_comment_parent && issue.parent_id.present?
        parent = Issue.find_by(id: issue.parent_id)
        if parent.present?
          parent.reload
          parent_journal = parent.init_journal(User.current, rule.action_comment)
          parent_journal.save
        end
      end
    end
  end
end
