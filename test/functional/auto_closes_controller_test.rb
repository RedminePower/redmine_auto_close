# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class AutoClosesControllerTest < ActionController::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles, :issue_statuses, :trackers

  def setup
    @admin = User.find(1)
    @non_admin = User.find(2)
    @closed_status = IssueStatus.where(is_closed: true).first
    @project = Project.find(1)

    @auto_close = AutoClose.create!(
      title: 'Test Rule',
      is_enabled: true,
      action_status: @closed_status.id
    )
  end

  # Access control tests
  test 'should require admin for index' do
    @request.session[:user_id] = @non_admin.id
    get :index
    assert_response :forbidden
  end

  test 'should allow admin to access index' do
    @request.session[:user_id] = @admin.id
    get :index
    assert_response :success
  end

  test 'should require admin for show' do
    @request.session[:user_id] = @non_admin.id
    get :show, params: { id: @auto_close.id }
    assert_response :forbidden
  end

  test 'should require admin for new' do
    @request.session[:user_id] = @non_admin.id
    get :new
    assert_response :forbidden
  end

  test 'should require admin for create' do
    @request.session[:user_id] = @non_admin.id
    post :create, params: {
      auto_close: {
        title: 'New Rule',
        action_status: @closed_status.id,
      },
    }
    assert_response :forbidden
  end

  test 'should require admin for edit' do
    @request.session[:user_id] = @non_admin.id
    get :edit, params: { id: @auto_close.id }
    assert_response :forbidden
  end

  test 'should require admin for update' do
    @request.session[:user_id] = @non_admin.id
    patch :update, params: {
      id: @auto_close.id,
      auto_close: { title: 'Updated' },
    }
    assert_response :forbidden
  end

  test 'should require admin for destroy' do
    @request.session[:user_id] = @non_admin.id
    delete :destroy, params: { id: @auto_close.id }
    assert_response :forbidden
  end

  # Index action tests
  test 'should get index' do
    @request.session[:user_id] = @admin.id
    get :index
    assert_response :success
    assert response.body.include?(@auto_close.title)
  end

  test 'should migrate project_pattern on index' do
    auto_close_with_pattern = AutoClose.create!(
      title: 'Pattern Rule',
      action_status: @closed_status.id,
      project_pattern: 'ecookbook'
    )

    @request.session[:user_id] = @admin.id
    get :index

    auto_close_with_pattern.reload
    assert auto_close_with_pattern.project_ids.any?
    assert_nil auto_close_with_pattern.project_pattern
  end

  # Show action tests
  test 'should show auto_close' do
    @request.session[:user_id] = @admin.id
    get :show, params: { id: @auto_close.id }
    assert_response :success
    assert response.body.include?(@auto_close.title)
  end

  test 'should return 404 for non-existent auto_close' do
    @request.session[:user_id] = @admin.id
    assert_raises(ActiveRecord::RecordNotFound) do
      get :show, params: { id: 99_999 }
    end
  end

  # New action tests
  test 'should get new' do
    @request.session[:user_id] = @admin.id
    get :new
    assert_response :success
  end

  # Create action tests
  test 'should create auto_close' do
    @request.session[:user_id] = @admin.id

    assert_difference('AutoClose.count', 1) do
      post :create, params: {
        auto_close: {
          title: 'New Auto Close Rule',
          is_enabled: true,
          action_status: @closed_status.id,
          project_ids: [@project.id.to_s, ''],
        },
      }
    end

    auto_close = AutoClose.last
    assert_redirected_to auto_close_path(auto_close)
    assert_equal 'New Auto Close Rule', auto_close.title
    assert_equal [@project.id], auto_close.project_ids
  end

  test 'should handle project_ids parameter correctly' do
    @request.session[:user_id] = @admin.id

    post :create, params: {
      auto_close: {
        title: 'Test',
        action_status: @closed_status.id,
        project_ids: ['1', '2', '', '3'],
      },
    }

    assert_equal [1, 2, 3], AutoClose.last.project_ids
  end

  test 'should render new on create failure' do
    @request.session[:user_id] = @admin.id

    assert_no_difference('AutoClose.count') do
      post :create, params: {
        auto_close: {
          title: '', # Invalid - title required
        },
      }
    end

    assert_response :success
  end

  # Edit action tests
  test 'should get edit' do
    @request.session[:user_id] = @admin.id
    get :edit, params: { id: @auto_close.id }
    assert_response :success
  end

  # Update action tests
  test 'should update auto_close' do
    @request.session[:user_id] = @admin.id

    patch :update, params: {
      id: @auto_close.id,
      auto_close: {
        title: 'Updated Title',
        project_ids: [@project.id.to_s],
      },
    }

    assert_redirected_to auto_close_path(@auto_close)
    @auto_close.reload
    assert_equal 'Updated Title', @auto_close.title
    assert_equal [@project.id], @auto_close.project_ids
  end

  test 'should render edit on update failure' do
    @request.session[:user_id] = @admin.id

    patch :update, params: {
      id: @auto_close.id,
      auto_close: {
        title: '', # Invalid
        action_status: nil,
        action_assigned_to: nil,
        action_comment: nil,
      },
    }

    assert_response :success
  end

  # Skipping stale object test - AutoClose doesn't have optimistic locking enabled

  # Destroy action tests
  test 'should destroy auto_close' do
    @request.session[:user_id] = @admin.id

    assert_difference('AutoClose.count', -1) do
      delete :destroy, params: { id: @auto_close.id }
    end

    assert_redirected_to auto_closes_path
  end

  # Skipping update_all test - action doesn't exist in this version

  # Additional validation tests
  test 'should filter empty project_ids on create' do
    @request.session[:user_id] = @admin.id

    post :create, params: {
      auto_close: {
        title: 'Test',
        action_status: @closed_status.id,
        project_ids: ['', '', ''],
      },
    }

    assert_equal [], AutoClose.last.project_ids
  end

  test 'should filter empty project_ids on update' do
    @request.session[:user_id] = @admin.id

    patch :update, params: {
      id: @auto_close.id,
      auto_close: {
        project_ids: ['', ''],
      },
    }

    @auto_close.reload
    assert_equal [], @auto_close.project_ids
  end
end
