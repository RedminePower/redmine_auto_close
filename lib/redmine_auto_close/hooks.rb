module RedmineAutoClose
  class Hooks < Redmine::Hook::ViewListener
    def view_layouts_base_html_head(context = { })
        stylesheet_link_tag('auto_close.css', :plugin => 'redmine_auto_close')
    end
  end
end