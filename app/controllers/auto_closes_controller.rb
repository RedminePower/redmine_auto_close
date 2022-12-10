class AutoClosesController < ApplicationController
  layout 'admin'

  before_action :require_admin

  def index

  end

  def new
    @auto_close = AutoClose.new
  end
end
