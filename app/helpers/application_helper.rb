module ApplicationHelper
  APP_NAME = "EduPlatform".freeze

  # Page title: "<page> · EduPlatform", falling back to the app name alone.
  # Set the page part with `<% content_for :title, "Estudiantes" %>` in a view.
  def page_title
    page = content_for(:title)
    page.present? ? "#{page} · #{APP_NAME}" : APP_NAME
  end
end
