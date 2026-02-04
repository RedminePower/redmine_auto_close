# frozen_string_literal: true

module RedmineAutoClose
  class AutoCloseService
    # Resolve action_user to actual User object
    def self.resolve_action_user(rule, issue)
      case rule.action_user
      when AutoClose::ACTION_USER_ASSIGNEE
        issue.assigned_to
      when AutoClose::ACTION_USER_AUTHOR
        issue.author
      when AutoClose::ACTION_USER_PARENT_ASSIGNEE
        issue.parent&.assigned_to
      else
        User.find_by(id: rule.action_user)
      end
    end

    # Find expired issues matching a rule
    def self.find_expired_issues(rule)
      issues = Issue.joins(:status)
                    .includes(:custom_values)
                    .where('issues.due_date < ?', Date.today)
                    .where('issue_statuses.is_closed = ?', false)

      # Filter by action_status if set (skip issues already at target status)
      if rule.action_status.present?
        issues = issues.where.not(status_id: rule.action_status)
      end

      # Filter by project_ids
      if rule.project_ids.present? && rule.project_ids.any?
        issues = issues.where(project_id: rule.project_ids)
      end

      # Filter by tracker
      if rule.trigger_tracker.present?
        issues = issues.where(tracker_id: rule.trigger_tracker)
      end

      # Filter by status
      if rule.trigger_status.present?
        issues = issues.where(status_id: rule.trigger_status)
      end

      # Filter by subject pattern
      if rule.trigger_subject_pattern.present?
        pattern = rule.trigger_subject_pattern
        issues = issues.select { |issue| issue.subject =~ Regexp.new(pattern) }
      end

      # Filter by custom field
      if rule.trigger_custom_field.present?
        issues = issues.select do |issue|
          cf_value = issue.custom_field_values.detect { |v|
            v.custom_field_id == rule.trigger_custom_field
          }
          if cf_value.present?
            cf_value_to_bool = (cf_value.value == '1')
            cf_value_to_bool == rule.trigger_custom_field_boolean
          else
            false
          end
        end
      end

      # Convert to array if it's still a relation
      issues.respond_to?(:to_a) ? issues.to_a : issues
    end

    # Check if an auto_close rule matches the given issue (for children closed trigger)
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
      has_comment = rule.action_comment.present?

      # Save issue changes with journal entry
      if needs_update || has_comment
        retries = 0
        begin
          issue.reload # Always reload to get latest version
          # Initialize journal BEFORE making changes (required for Redmine to track changes)
          issue.init_journal(User.current, has_comment ? rule.action_comment : nil)
          issue.status_id = new_status_id if new_status_id.present?
          issue.assigned_to_id = new_assigned_to_id if new_assigned_to_id.present?
          issue.save
        rescue ActiveRecord::StaleObjectError
          raise if retries >= 2

          retries += 1
          retry
        end
      end

      # 親チケット（祖父）にもコメント追加
      if has_comment && rule.is_action_comment_parent && issue.parent_id.present?
        parent = Issue.find_by(id: issue.parent_id)
        if parent.present?
          parent.reload
          parent.init_journal(User.current, rule.action_comment)
          parent.save
        end
      end
    end
  end
end
