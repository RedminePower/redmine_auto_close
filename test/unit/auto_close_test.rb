# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class AutoCloseTest < ActiveSupport::TestCase
  fixtures :projects, :trackers, :issue_statuses, :users

  def setup
    @project = Project.find(1)
    @tracker = Tracker.find(1)
    @closed_status = IssueStatus.where(is_closed: true).first
  end

  # Validation tests
  test 'should require title' do
    auto_close = AutoClose.new
    assert_not auto_close.valid?
    assert auto_close.errors[:title].present?
  end

  test 'should require at least one action' do
    auto_close = AutoClose.new(
      title: 'Test Rule',
      action_status: nil,
      action_assigned_to: nil,
      action_comment: nil
    )
    assert_not auto_close.valid?
    assert auto_close.errors[:action_status].present?
  end

  test 'should be valid with title and at least one action' do
    auto_close = AutoClose.new(
      title: 'Test Rule',
      action_status: @closed_status.id
    )
    assert auto_close.valid?
  end

  test 'should validate project_pattern as valid regex' do
    auto_close = AutoClose.new(
      title: 'Test Rule',
      action_status: @closed_status.id,
      project_pattern: '[invalid'
    )
    assert_not auto_close.valid?
    assert auto_close.errors[:project_pattern].present?
  end

  test 'should validate trigger_subject_pattern as valid regex' do
    auto_close = AutoClose.new(
      title: 'Test Rule',
      action_status: @closed_status.id,
      trigger_subject_pattern: '*invalid'
    )
    assert_not auto_close.valid?
    assert auto_close.errors[:trigger_subject_pattern].present?
  end

  # project_ids serialization tests
  test 'should serialize and deserialize project_ids' do
    auto_close = AutoClose.create!(
      title: 'Test Rule',
      action_status: @closed_status.id,
      project_ids: [1, 2, 3]
    )
    auto_close.reload
    assert_equal [1, 2, 3], auto_close.project_ids
  end

  test 'should return empty array when project_ids is nil' do
    auto_close = AutoClose.create!(
      title: 'Test Rule',
      action_status: @closed_status.id
    )
    assert_equal [], auto_close.project_ids
  end

  test 'should convert string project_ids to integers' do
    auto_close = AutoClose.new(title: 'Test', action_status: @closed_status.id)
    auto_close.project_ids = %w[1 2 3]
    assert_equal [1, 2, 3], auto_close.project_ids
  end

  # Trigger type methods
  test 'should return correct trigger type label' do
    auto_close = AutoClose.new(
      title: 'Test Rule',
      trigger_type: AutoClose::TRIGGER_TYPES_CHILDREN_CLOSED
    )
    assert_equal :label_triggers_child_closed, auto_close.trigger_type_label
  end

  test 'is_trigger_child_closed? should return true for children closed trigger' do
    auto_close = AutoClose.new(trigger_type: AutoClose::TRIGGER_TYPES_CHILDREN_CLOSED)
    assert auto_close.is_trigger_child_closed?
  end

  test 'is_trigger_expired? should return true for expired trigger' do
    auto_close = AutoClose.new(trigger_type: AutoClose::TRIGGER_TYPES_EXPIRED)
    assert auto_close.is_trigger_expired?
  end

  test 'available? should return is_enabled value' do
    auto_close = AutoClose.new(is_enabled: true)
    assert auto_close.available?

    auto_close.is_enabled = false
    assert_not auto_close.available?
  end

  # Label methods
  test 'project_ids_label should return project names' do
    auto_close = AutoClose.create!(
      title: 'Test Rule',
      action_status: @closed_status.id,
      project_ids: [1]
    )
    assert_not_empty auto_close.project_ids_label
    assert auto_close.project_ids_label.include?(Project.find(1).name)
  end

  test 'trigger_tracker_label should return tracker name' do
    auto_close = AutoClose.new(trigger_tracker: @tracker.id)
    assert_equal @tracker.name, auto_close.trigger_tracker_label
  end

  test 'trigger_status_label should return status name' do
    status = IssueStatus.first
    auto_close = AutoClose.new(trigger_status: status.id)
    assert_equal status.name, auto_close.trigger_status_label
  end

  # Default values
  test 'should set default values on initialization' do
    auto_close = AutoClose.new
    assert auto_close.is_enabled
  end

  # Migration helper
  test 'migrate_project_pattern should convert pattern to project_ids' do
    auto_close = AutoClose.create!(
      title: 'Test Rule',
      action_status: @closed_status.id,
      project_pattern: 'ecookbook'
    )

    auto_close.migrate_project_pattern
    auto_close.reload

    assert auto_close.project_ids.include?(@project.id)
    assert_nil auto_close.project_pattern
  end
end
