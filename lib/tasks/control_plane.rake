# S0's only alta path for platform_admins: no self-registration, no invite UI.
# Guarded like bin/migrate's EDU_MIGRATOR_PASSWORD check — a non-empty env var
# you have to set on purpose, not a flag you can pass by accident.
namespace :control_plane do
  desc "Bootstrap a platform_admin (idempotent by email, audited). " \
       "Usage: CONTROL_PLANE_BOOTSTRAP=1 [ADMIN_EMAIL=… ADMIN_NAME=… ADMIN_PASSWORD=…] bin/rails control_plane:create_admin"
  task create_admin: :environment do
    abort "Set CONTROL_PLANE_BOOTSTRAP=1 to run this task." if ENV["CONTROL_PLANE_BOOTSTRAP"] != "1"

    read_line = ->(label) { print label; $stdin.gets&.strip }
    read_password = lambda do |label|
      require "io/console"
      print label
      pw = $stdin.noecho(&:gets)&.strip
      puts
      pw
    end

    email = ENV["ADMIN_EMAIL"].presence || read_line.call("Email: ")
    name  = ENV["ADMIN_NAME"].presence  || read_line.call("Nombre: ")
    password = ENV["ADMIN_PASSWORD"].presence || read_password.call("Password: ")

    normalized_email = email.to_s.downcase.strip

    if (existing = ControlPlane::PlatformAdmin.find_by(email: normalized_email))
      puts "Ya existe un platform_admin con ese correo (#{existing.id}) — no se duplica."
      next
    end

    admin = ControlPlane::PlatformAdmin.create!(
      email: normalized_email, name: name, status: "active",
      password: password, password_confirmation: password
    )

    ControlPlane::Audit.log(action: "platform_admin.bootstrapped", platform_admin: admin, target: admin)

    puts "Creado platform_admin #{admin.email} (#{admin.id})."
  end

  desc "Seed the initial billing catalog (addons + example plan). Idempotent by key."
  task seed_catalog: :environment do
    ControlPlane::SeedCatalog.call
    puts "Catálogo sembrado: #{ControlPlane::Addon.count} addons, #{ControlPlane::Plan.count} planes."
  end
end
