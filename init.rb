Redmine::Plugin.register :redmine_auto_close do
  name 'Redmine Auto Close plugin'
  author 'Redmine Power'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'https://www.en.redmine-power.com/'

  menu :admin_menu, :auto_closes,
    { :controller => 'auto_closes', :action => 'index' },
    :caption => :label_auto_close,
    :html => { :class => 'icon icon-auto_close'},
    :if => Proc.new { User.current.admin? }

end
