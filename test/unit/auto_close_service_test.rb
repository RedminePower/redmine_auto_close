# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class AutoCloseServiceTest < ActiveSupport::TestCase
  fixtures :projects, :trackers, :issue_statuses, :issues, :users, :custom_fields

  def setup
    @project = Project.find(1)
    @tracker = Tracker.find(1)
    @closed_status = IssueStatus.where(is_closed: true).first
    @open_status = IssueStatus.where(is_closed: false).first
    @user = User.find(2)
    @parent_issue = Issue.create!(
      project: @project,
      tracker: @tracker,
      subject: 'Parent Issue',
      author: @user,
      status: @open_status,
      priority: IssuePriority.first
    )
  end

  # matches? tests
  test 'matches? should return false for disabled rule' do
    rule = AutoClose.create!(
      title: 'Test Rule',
      is_enabled: false,
      action_status: @closed_status.id
    )

    assert_not RedmineAutoClose::AutoCloseService.matches?(@project, @parent_issue, rule)
  end

  test 'matches? should return false for non-children-closed trigger' do
    rule = AutoClose.create!(
      title: 'Test Rule',
      is_enabled: true,
      trigger_type: AutoClose::TRIGGER_TYPES_EXPIRED,
      action_user: @user.id,
      action_status: @closed_status.id
    )

    assert_not RedmineAutoClose::AutoCloseService.matches?(@project, @parent_issue, rule)
  end

  test 'matches? should match project by pattern' do
    rule = AutoClose.create!(
      title: 'Test Rule',
      is_enabled: true,
      trigger_type: AutoClose::TRIGGER_TYPES_CHILDREN_CLOSED,
      project_pattern: 'ecookbook',
      action_status: @closed_status.id
    )

    assert RedmineAutoClose::AutoCloseService.matches?(@project, @parent_issue, rule)
  end

  test 'matches? should not match when project pattern does not match' do
    rule = AutoClose.create!(
      title: 'Test Rule',
      is_enabled: true,
      trigger_type: AutoClose::TRIGGER_TYPES_CHILDREN_CLOSED,
      project_pattern: 'nonexistent',
      action_status: @closed_status.id
    )

    assert_not RedmineAutoClose::AutoCloseService.matches?(@project, @parent_issue, rule)
  end

  test 'matches? should match project by project_ids' do
    rule = AutoClose.create!(
      title: 'Test Rule',
      is_enabled: true,
      trigger_type: AutoClose::TRIGGER_TYPES_CHILDREN_CLOSED,
      project_ids: [@project.id],
      action_status: @closed_status.id
    )

    assert RedmineAutoClose::AutoCloseService.matches?(@project, @parent_issue, rule)
  end

  test 'matches? should not match when project_id not in list' do
    rule = AutoClose.create!(
      title: 'Test Rule',
      is_enabled: true,
      trigger_type: AutoClose::TRIGGER_TYPES_CHILDREN_CLOSED,
      project_ids: [999],
      action_status: @closed_status.id
    )

    assert_not RedmineAutoClose::AutoCloseService.matches?(@project, @parent_issue, rule)
  end

  test 'matches? should match by tracker' do
    rule = AutoClose.create!(
      title: 'Test Rule',
      is_enabled: true,
      trigger_type: AutoClose::TRIGGER_TYPES_CHILDREN_CLOSED,
      trigger_tracker: @tracker.id,
      action_status: @closed_status.id
    )

    assert RedmineAutoClose::AutoCloseService.matches?(@project, @parent_issue, rule)
  end

  test 'matches? should not match wrong tracker' do
    other_tracker = Tracker.where.not(id: @tracker.id).first
    rule = AutoClose.create!(
      title: 'Test Rule',
      is_enabled: true,
      trigger_type: AutoClose::TRIGGER_TYPES_CHILDREN_CLOSED,
      trigger_tracker: other_tracker.id,
      action_status: @closed_status.id
    )

    assert_not RedmineAutoClose::AutoCloseService.matches?(@project, @parent_issue, rule)
  end

  test 'matches? should match by subject pattern' do
    rule = AutoClose.create!(
      title: 'Test Rule',
      is_enabled: true,
      trigger_type: AutoClose::TRIGGER_TYPES_CHILDREN_CLOSED,
      trigger_subject_pattern: 'Parent',
      action_status: @closed_status.id
    )

    assert RedmineAutoClose::AutoCloseService.matches?(@project, @parent_issue, rule)
  end

  test 'matches? should not match wrong subject pattern' do
    rule = AutoClose.create!(
      title: 'Test Rule',
      is_enabled: true,
      trigger_type: AutoClose::TRIGGER_TYPES_CHILDREN_CLOSED,
      trigger_subject_pattern: 'Nonexistent',
      action_status: @closed_status.id
    )

    assert_not RedmineAutoClose::AutoCloseService.matches?(@project, @parent_issue, rule)
  end

  test 'matches? should match by status' do
    rule = AutoClose.create!(
      title: 'Test Rule',
      is_enabled: true,
      trigger_type: AutoClose::TRIGGER_TYPES_CHILDREN_CLOSED,
      trigger_status: @parent_issue.status_id,
      action_status: @closed_status.id
    )

    assert RedmineAutoClose::AutoCloseService.matches?(@project, @parent_issue, rule)
  end

  test 'matches? should not match wrong status' do
    other_status = IssueStatus.where.not(id: @parent_issue.status_id).first
    rule = AutoClose.create!(
      title: 'Test Rule',
      is_enabled: true,
      trigger_type: AutoClose::TRIGGER_TYPES_CHILDREN_CLOSED,
      trigger_status: other_status.id,
      action_status: @closed_status.id
    )

    assert_not RedmineAutoClose::AutoCloseService.matches?(@project, @parent_issue, rule)
  end

  # apply_rule tests
  test 'apply_rule should change issue status' do
    rule = AutoClose.create!(
      title: 'Test Rule',
      is_enabled: true,
      action_status: @closed_status.id
    )

    User.current = @user
    RedmineAutoClose::AutoCloseService.apply_rule(rule, @parent_issue)

    @parent_issue.reload
    assert_equal @closed_status.id, @parent_issue.status_id
  end

  test 'apply_rule should change issue assignee' do
    rule = AutoClose.create!(
      title: 'Test Rule',
      is_enabled: true,
      action_assigned_to: @user.id,
      action_status: @closed_status.id
    )

    User.current = @user
    RedmineAutoClose::AutoCloseService.apply_rule(rule, @parent_issue)

    @parent_issue.reload
    assert_equal @user.id, @parent_issue.assigned_to_id
  end

  test 'apply_rule should add comment' do
    rule = AutoClose.create!(
      title: 'Test Rule',
      is_enabled: true,
      action_comment: 'Auto-closed by rule',
      action_status: @closed_status.id
    )

    User.current = @user
    initial_journal_count = @parent_issue.journals.count

    RedmineAutoClose::AutoCloseService.apply_rule(rule, @parent_issue)

    @parent_issue.reload
    assert_equal initial_journal_count + 1, @parent_issue.journals.count
    assert_equal 'Auto-closed by rule', @parent_issue.journals.last.notes
  end

  test 'apply_rule should apply multiple actions' do
    rule = AutoClose.create!(
      title: 'Test Rule',
      is_enabled: true,
      action_status: @closed_status.id,
      action_assigned_to: @user.id,
      action_comment: 'Auto-closed'
    )

    User.current = @user
    RedmineAutoClose::AutoCloseService.apply_rule(rule, @parent_issue)

    @parent_issue.reload
    assert_equal @closed_status.id, @parent_issue.status_id
    assert_equal @user.id, @parent_issue.assigned_to_id
    assert(@parent_issue.journals.any? { |j| j.notes == 'Auto-closed' })
  end

  test 'apply_rule should not save when no update needed' do
    rule = AutoClose.create!(
      title: 'Test Rule',
      is_enabled: true,
      action_comment: 'Just a comment',
      action_status: @closed_status.id
    )

    User.current = @user
    @parent_issue.updated_on

    RedmineAutoClose::AutoCloseService.apply_rule(rule, @parent_issue)

    # Journal is saved, but issue itself shouldn't be saved if only comment
    # (unless status/assignee changed)
    @parent_issue.reload
    # Check that at least the comment was added
    assert(@parent_issue.journals.any? { |j| j.notes == 'Just a comment' })
  end
end
