require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module EduPlatform
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

# RLS policies are created with raw SQL in migrations, which the Ruby schema
# dumper cannot represent. Use the SQL format so db/structure.sql (via
# pg_dump) preserves policies, FORCE RLS, and the citext extension.
config.active_record.schema_format = :sql

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

# --- Bounded-context autoloading ----------------------------------------
# app/domains is a direct child of app/, so Rails already registers it as an
# autoload ROOT. A root contributes no namespace, so each subdirectory
# becomes a top-level namespace with ZERO extra config:
#   app/domains/cafeteria/checkout.rb -> Cafeteria::Checkout
#
# The only customization we need: within a domain we keep the familiar Rails
# folders (models/ queries/ services/ jobs/ policies/) but COLLAPSE them so
# they do not leak into the constant path. Names stay flat and greppable --
#   app/domains/core/models/student.rb    -> Core::Student
#   app/domains/core/queries/students.rb  -> Core::Students   (a Query object)
# instead of Core::Models::Student. One namespace per bounded context.
Rails.autoloaders.main.collapse(
  Rails.root.glob("app/domains/*/{models,queries,services,jobs,policies}")
)

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
