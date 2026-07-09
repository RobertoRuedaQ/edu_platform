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

  desc "Push a student headcount snapshot (S3a). Runs synchronously, under the " \
       "tenant's own GUC — no worker process required. " \
       "Usage: bin/rails control_plane:snapshot_headcount[institution_id] (all institutions if omitted). " \
       "Recurring schedule deferred — invoke manually or from an external scheduler for now."
  task :snapshot_headcount, [ :institution_id ] => :environment do |_t, args|
    institutions = args[:institution_id].presence ? Core::Institution.where(id: args[:institution_id]) : Core::Institution.all

    institutions.find_each do |institution|
      snapshot = Core::Headcount::SnapshotJob.run_now_for(institution)
      puts "#{institution.name}: headcount=#{snapshot.headcount} as_of=#{snapshot.as_of_date}"
    end
  end

  desc "Roll up usage_events into usage_daily_rollups for one day (S3a). " \
       "Usage: bin/rails control_plane:rollup_usage[2026-07-09] (yesterday if omitted). " \
       "Idempotent — safe to re-run. Recurring schedule deferred."
  task :rollup_usage, [ :usage_date ] => :environment do |_t, args|
    usage_date = args[:usage_date].presence ? Date.parse(args[:usage_date]) : Date.yesterday
    ControlPlane::Usage::RollupJob.perform_now(usage_date)
    count = ControlPlane::UsageDailyRollup.where(usage_date: usage_date).count
    puts "Rollup de #{usage_date}: #{count} buckets (institución × addon × unidad)."
  end
end
