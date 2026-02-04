# frozen_string_literal: true

class AutoClosesController < ApplicationController
  layout 'admin'

  before_action :require_admin
  before_action :find_auto_close, except: %i[index new create]

  helper :sort
  include SortHelper

  def index
    sort_init 'id', 'desc'
    sort_update %w[id path_pattern]
    items = AutoClose.order(sort_clause)
    items.each(&:migrate_project_pattern)
    @auto_closes = items
  end

  def new
    @auto_close = AutoClose.new
  end

  def create
    @auto_close = AutoClose.new(auto_close_params)
    @auto_close.project_ids = params[:auto_close][:project_ids]&.select(&:present?)&.map(&:to_i) || []

    if @auto_close.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to auto_close_path(@auto_close.id)
    else
      render action: 'new'
    end
  end

  def show
  end

  def edit
  end

  def update
    @auto_close.attributes = auto_close_params
    @auto_close.project_ids = params[:auto_close][:project_ids]&.select(&:present?)&.map(&:to_i) || []
    if @auto_close.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to auto_close_path(@auto_close.id)
    else
      render action: 'edit'
    end
  rescue ActiveRecord::StaleObjectError
    flash.now[:error] = l(:notice_locking_conflict)
    render action: 'edit'
  end

  def update_all
    AutoClose.update_all(auto_close_params.to_hash)

    flash[:notice] = l(:notice_successful_update)
    redirect_to auto_closes_path
  end

  def destroy
    @auto_close.destroy
    redirect_to auto_closes_path
  end

  private

  def find_auto_close
    @auto_close = AutoClose.find(params[:id])
    render_404 unless @auto_close
  end

  def auto_close_params
    params.require(:auto_close)
      .permit(
        :title,
        :is_enabled,
        :project_pattern,
        :trigger_type,
        :trigger_tracker,
        :trigger_subject_pattern,
        :trigger_status,
        :trigger_custom_field,
        :trigger_custom_field_boolean,
        :action_user,
        :max_issues_per_run,
        :action_status,
        :action_assigned_to,
        :action_comment,
        :is_action_comment_parent,
        :action_assigned_to_custom_field,
        :project_ids
      )
  end
end
