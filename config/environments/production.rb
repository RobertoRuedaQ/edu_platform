require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # --- Just-In-Time compilation -------------------------------------------
  # Enable YJIT explicitly. This is a no-op on a runtime that lacks YJIT, so
  # it is safe to leave on.
  #
  # DO NOT enable ZJIT. As of the Ruby 4.0.x line ZJIT is experimental; it is
  # not sanctioned for this project and must never be relied on in production
  # (i.e. never set `config.zjit = true` or pass `--zjit` to the runtime).
  config.yjit = true

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # A misconfigured/unreachable SMTP server must be loud, never a silently
  # dropped OTP/invitation — this is production, not the dev :file sink.
  config.action_mailer.raise_delivery_errors = true

  # Set host to be used by links generated in mailer templates (invitation
  # links resolve the institution's OWN subdomain separately — see
  # InvitationMailer — this host is only the fallback for links that don't).
  config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "example.com") }

  # Generic SMTP — works with ANY provider (Postmark, SendGrid, SES, Mailgun,
  # a personal mailbox, …) without a provider-specific gem: every major
  # provider exposes an SMTP relay, so this one transport covers all of them.
  # Real values come from `bin/rails credentials:edit` (key `smtp:`) OR the
  # matching SMTP_* env vars (env wins when both are set — useful on hosts
  # that inject secrets as env vars, e.g. Render/Fly/Heroku).
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address:              ENV.fetch("SMTP_ADDRESS", Rails.application.credentials.dig(:smtp, :address)),
    port:                 Integer(ENV.fetch("SMTP_PORT", Rails.application.credentials.dig(:smtp, :port) || 587)),
    domain:               ENV.fetch("SMTP_DOMAIN", Rails.application.credentials.dig(:smtp, :domain)),
    user_name:            ENV.fetch("SMTP_USERNAME", Rails.application.credentials.dig(:smtp, :user_name)),
    password:             ENV.fetch("SMTP_PASSWORD", Rails.application.credentials.dig(:smtp, :password)),
    authentication:       :plain,
    enable_starttls_auto: true
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
