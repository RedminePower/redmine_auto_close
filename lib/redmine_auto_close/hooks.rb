# frozen_string_literal: true

module RedmineAutoClose
  class Hooks < Redmine::Hook::ViewListener
    # Inject CSS into all views
    def view_layouts_base_html_head(_context = {})
      stylesheet_link_tag('auto_close.css', plugin: :redmine_auto_close)
    end
  end
end
