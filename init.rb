Redmine::Plugin.register :redmine_auto_close do
  name 'Redmine Auto Close plugin'
  author 'Redmine Power'
  description 'This plugin can close a ticket when a specified condition is triggered.'
  version '1.0.0'
  url 'https://github.com/RedminePower/redmine_auto_close'
  author_url 'https://www.redmine-power.com/'

  menu :admin_menu, :auto_closes,
    { :controller => 'auto_closes', :action => 'index' },
    :caption => :label_auto_close,
    :html => { :class => 'icon icon-auto_close'},
    :if => Proc.new { User.current.admin? }

end
