# frozen_string_literal: true

module RedmineAutoClose
  class AutoCloseService
    # Check if an auto_close rule matches the given issue
    def self.matches?(project, parent_issue, item)
      # Check if enabled
      return false unless item.available?

      # Check trigger type (must be children closed)
      return false unless item.is_triger_child_closed?

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
      if item.trigger_subject_pattern.present? && !parent_issue.subject =~ (Regexp.new(item.trigger_subject_pattern))
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
        if cf_value.present? && cf_value.value != item.trigger_custom_field_boolean
          return false
        end
      end

      true
    end

    # Apply an auto_close rule to an issue
    def self.apply_rule(rule, issue)
      needs_update = false

      # Add comment if configured
      if rule.action_comment.present?
        journal = issue.init_journal(User.current, rule.action_comment)
        journal.save
      end

      # Change status if configured
      if rule.action_status.present?
        issue.status_id = rule.action_status
        needs_update = true
      end

      # Change assignee if configured
      if rule.action_assigned_to.present?
        issue.assigned_to_id = rule.action_assigned_to
        needs_update = true
      # Or set assignee from custom field
      elsif rule.action_assigned_to_custom_field.present?
        cf_value = issue.custom_field_values.detect { |v|
          v.custom_field_id == rule.action_assigned_to_custom_field
        }
        if cf_value.present?
          issue.assigned_to_id = cf_value.value
          needs_update = true
        end
      end

      issue.save if needs_update
    end
  end
end
