class AutoClosesController < ApplicationController
  layout 'admin'

  before_action :require_admin
  before_action :find_auto_close, :except => [:index, :new, :create]

  helper :sort
  include SortHelper

  def index
    sort_init 'id', 'desc'
    sort_update %w(id path_pattern)
    @auto_closes = AutoClose.order(sort_clause)
  end

  def new
    @auto_close = AutoClose.new
  end

  def create
    @auto_close = AutoClose.new(auto_close_params)

    if @auto_close.save    
      flash[:notice] = l(:notice_successful_create)
      redirect_to auto_close_path(@auto_close.id)
    else
      render :action => 'new'
    end
  end

  def show
  end

  def edit
  end

  def update
    @auto_close.attributes = auto_close_params
    if @auto_close.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to auto_close_path(@auto_close.id)
    else
      render :action => 'edit'
    end
  rescue ActiveRecord::StaleObjectError
    flash.now[:error] = l(:notice_locking_conflict)
    render :action => 'edit'
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
        :trigger_type, 
        :trigger_tracker, 
        :trigger_status, 
        :trigger_custom_field, 
        :trigger_custom_field_boolean, 
        :action_user, 
        :action_status, 
        :action_assinged_to, 
        :action_comment, 
        :is_action_comment_parent
      )
  end

end
