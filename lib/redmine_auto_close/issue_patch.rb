# frozen_string_literal: true

module RedmineAutoClose
  module IssuePatch
    extend ActiveSupport::Concern

    included do
      # Register callbacks
      before_save :store_status_before_change
      after_save :trigger_parent_auto_close

      private

      def store_status_before_change
        @status_before_change = status_id_was if status_id_changed?
      end

      def trigger_parent_auto_close
        # Only process if this issue has a parent
        return if parent_id.blank?

        # Only process if status changed
        return if @status_before_change.blank?

        # Only process if new status is closed
        return unless closed?

        # Check if all sibling issues are also closed
        parent_issue = Issue.find_by(id: parent_id)
        return unless parent_issue

        # Check all children (descendants) of parent
        all_children_closed = parent_issue.descendants.visible.all? do |child|
          child.id == id || IssueStatus.find_by(id: child.status_id)&.is_closed?
        end

        return unless all_children_closed

        # Find matching auto_close rules
        items = AutoClose.all.order(:id).select do |item|
          RedmineAutoClose::AutoCloseService.matches?(project, parent_issue, item)
        end
        return if items.empty?

        # Apply the first matching rule
        RedmineAutoClose::AutoCloseService.apply_rule(items.first, parent_issue)
      end
    end
  end
end
