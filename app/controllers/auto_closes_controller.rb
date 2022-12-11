class AutoClosesController < ApplicationController
  layout 'admin'

  before_action :require_admin
  before_action :find_view_customize, :except => [:index, :new, :create]

  def index

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

  def find_view_customize
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
        :action_user, 
        :action_status, 
        :action_assinged_to, 
        :action_comment, 
        :is_action_comment_parent
      )
  end

end
