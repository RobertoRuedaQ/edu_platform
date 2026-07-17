class ApplicationMailer < ActionMailer::Base
  # Real value comes from MAILER_FROM (set alongside the SMTP_* env vars/
  # credentials in config/environments/production.rb) — this default only
  # matters in development/test, where nothing actually gets delivered
  # over the network.
  default from: ENV.fetch("MAILER_FROM", "no-reply@edu-platform.test")
  layout "mailer"
end
