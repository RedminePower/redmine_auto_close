# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class IssueAutoCloseTest < ActiveSupport::TestCase
  fixtures :projects, :trackers, :issue_statuses, :users, :roles, :members, :member_roles

  def setup
    @project = Project.find(1)
    @tracker = Tracker.find(1)
    @open_status = IssueStatus.where(is_closed: false).first
    @closed_status = IssueStatus.where(is_closed: true).first
    @user = User.find(2)

    # Create parent issue
    @parent = Issue.create!(
      project: @project,
      tracker: @tracker,
      subject: 'Parent Issue',
      author: @user,
      status: @open_status,
      priority: IssuePriority.first
    )

    # Create child issues
    @child1 = Issue.create!(
      project: @project,
      tracker: @tracker,
      subject: 'Child 1',
      author: @user,
      status: @open_status,
      priority: IssuePriority.first,
      parent_issue_id: @parent.id
    )

    @child2 = Issue.create!(
      project: @project,
      tracker: @tracker,
      subject: 'Child 2',
      author: @user,
      status: @open_status,
      priority: IssuePriority.first,
      parent_issue_id: @parent.id
    )

    # Create auto_close rule
    @rule = AutoClose.create!(
      title: 'Auto-close parent when children done',
      is_enabled: true,
      trigger_type: AutoClose::TRIGGER_TYPES_CHILDREN_CLOSED,
      action_status: @closed_status.id,
      action_comment: 'All children completed'
    )

    User.current = @user
  end

  test 'should not auto-close parent when only one child is closed' do
    @child1.status_id = @closed_status.id
    @child1.save!

    @parent.reload
    assert_equal @open_status.id, @parent.status_id
  end

  test 'should auto-close parent when all children are closed' do
    # Close first child
    @child1.status_id = @closed_status.id
    @child1.save!

    # Close second child - should trigger parent auto-close
    @child2.status_id = @closed_status.id
    @child2.save!

    @parent.reload
    assert_equal @closed_status.id, @parent.status_id
  end

  test 'should add comment to parent when auto-closing' do
    initial_journal_count = @parent.journals.count

    @child1.status_id = @closed_status.id
    @child1.save!

    @child2.status_id = @closed_status.id
    @child2.save!

    @parent.reload
    assert_equal initial_journal_count + 1, @parent.journals.count
    assert_equal 'All children completed', @parent.journals.last.notes
  end

  test 'should not trigger when rule is disabled' do
    @rule.update!(is_enabled: false)

    @child1.status_id = @closed_status.id
    @child1.save!

    @child2.status_id = @closed_status.id
    @child2.save!

    @parent.reload
    assert_equal @open_status.id, @parent.status_id
  end

  test 'should respect project filter in rule' do
    other_project = Project.create!(
      name: 'Other Project',
      identifier: 'other-project'
    )
    @rule.update!(project_ids: [other_project.id])

    @child1.status_id = @closed_status.id
    @child1.save!

    @child2.status_id = @closed_status.id
    @child2.save!

    @parent.reload
    # Should not auto-close because project doesn't match rule
    assert_equal @open_status.id, @parent.status_id
  end

  test 'should respect tracker filter in rule' do
    other_tracker = Tracker.where.not(id: @tracker.id).first
    @rule.update!(trigger_tracker: other_tracker.id)

    @child1.status_id = @closed_status.id
    @child1.save!

    @child2.status_id = @closed_status.id
    @child2.save!

    @parent.reload
    # Should not auto-close because tracker doesn't match
    assert_equal @open_status.id, @parent.status_id
  end

  test 'should respect subject pattern filter in rule' do
    @rule.update!(trigger_subject_pattern: 'NonExistent')

    @child1.status_id = @closed_status.id
    @child1.save!

    @child2.status_id = @closed_status.id
    @child2.save!

    @parent.reload
    # Should not auto-close because subject doesn't match pattern
    assert_equal @open_status.id, @parent.status_id
  end

  test 'should work with subject pattern that matches' do
    @rule.update!(trigger_subject_pattern: 'Parent')

    @child1.status_id = @closed_status.id
    @child1.save!

    @child2.status_id = @closed_status.id
    @child2.save!

    @parent.reload
    # Should auto-close because subject matches pattern
    assert_equal @closed_status.id, @parent.status_id
  end

  test 'should not trigger when child status changes but not to closed' do
    another_open_status = IssueStatus.where(is_closed: false).where.not(id: @open_status.id).first
    skip 'Need multiple open statuses for this test' unless another_open_status

    @child1.status_id = another_open_status.id
    @child1.save!

    @parent.reload
    assert_equal @open_status.id, @parent.status_id
  end

  test 'should handle nested children (grandchildren)' do
    # Create a grandchild under child1
    grandchild = Issue.create!(
      project: @project,
      tracker: @tracker,
      subject: 'Grandchild',
      author: @user,
      status: @open_status,
      priority: IssuePriority.first,
      parent_issue_id: @child1.id
    )

    # Close child2
    @child2.reload # Reload to avoid stale object
    @child2.status_id = @closed_status.id
    @child2.save!

    # Close grandchild first
    grandchild.reload # Reload to avoid stale object
    grandchild.status_id = @closed_status.id
    grandchild.save!

    # Now close child1 - all its children (grandchild) are closed
    # This should trigger auto-close of parent since all children are closed
    @child1.reload # Reload to avoid stale object
    @child1.status_id = @closed_status.id
    @child1.save!

    @parent.reload
    # Parent should auto-close because both child1 and child2 are now closed
    assert_equal @closed_status.id, @parent.status_id
  end

  test 'should apply first matching rule when multiple rules match' do
    # Create a second rule with different comment
    AutoClose.create!(
      title: 'Second Rule',
      is_enabled: true,
      trigger_type: AutoClose::TRIGGER_TYPES_CHILDREN_CLOSED,
      action_status: @closed_status.id,
      action_comment: 'Second rule applied'
    )

    @child1.status_id = @closed_status.id
    @child1.save!

    @child2.status_id = @closed_status.id
    @child2.save!

    @parent.reload
    # Should apply first rule (by ID order)
    assert(@parent.journals.any? { |j| j.notes == 'All children completed' })
    assert_not(@parent.journals.any? { |j| j.notes == 'Second rule applied' })
  end

  test 'should not trigger for issues without parent' do
    orphan = Issue.create!(
      project: @project,
      tracker: @tracker,
      subject: 'Orphan Issue',
      author: @user,
      status: @open_status,
      priority: IssuePriority.first
    )

    # This should not raise an error
    assert_nothing_raised do
      orphan.reload # Reload to avoid stale object
      orphan.status_id = @closed_status.id
      orphan.save!
    end
  end
end
