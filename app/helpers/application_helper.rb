module ApplicationHelper
  APP_NAME = "EduPlatform".freeze

  # Page title: "<page> · EduPlatform", falling back to the app name alone.
  # Set the page part with `<% content_for :title, "Estudiantes" %>` in a view.
  def page_title
    page = content_for(:title)
    page.present? ? "#{page} · #{APP_NAME}" : APP_NAME
  end

  # Registry entries the current actor may see, ordered. Filtered with can?
  # (cosmetic show/hide only) — every destination still gates with authorize!.
  def nav_items
    Navigation::Registry.sorted.select { |item| can?(item.permission) }
  end

  # STUB signed-in person for the shell header/switcher.
  # TODO: reemplazar por el usuario autenticado real.
  def current_actor
    @current_actor ||= CurrentActor.new
  end
end
