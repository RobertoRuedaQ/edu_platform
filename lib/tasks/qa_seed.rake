# QA-only helpers for a manual visual sweep of the app across every role.
# Attaches real logins to the already-seeded "colegio-san-jose" school
# (db/seeds.rb) instead of inventing isolated fake data, so each identity
# below carries real grades/enrollments/guardians/etc. Safe to re-run.
QA_PASSWORD = "EduPlatformQA2026!".freeze
QA_INSTITUTION_SLUG = "colegio-san-jose".freeze

namespace :qa do
  desc "Crea un login funcional por rol (RBAC + student + guardian + platform_admin) " \
       "sobre la institución sembrada '#{QA_INSTITUTION_SLUG}', y escribe tmp/qa_credentials.md. " \
       "Uso: bin/rails qa:seed_role_logins"
  task seed_role_logins: :environment do
    abort "qa:seed_role_logins solo corre en development." unless Rails.env.development?

    institution = Core::Institution.find_by(slug: QA_INSTITUTION_SLUG)
    abort "No existe '#{QA_INSTITUTION_SLUG}'. Corre primero: bin/rails db:seed" unless institution

    with_tenant = lambda do |&blk|
      ActiveRecord::Base.transaction do
        Tenant::Guc.set_local(institution.id)
        blk.call
      end
    end

    IdentityAccess::SeedPermissions.call

    ensure_password = lambda do |user|
      next unless user.password_digest.blank?
      user.update!(password: QA_PASSWORD, password_confirmation: QA_PASSWORD)
    end

    # ---- 1) Real RBAC roles + permissions (Role/RolePermission have zero
    # seed data anywhere else — mirror the UI stub's data into real rows). ----
    roles_by_key = {}
    IdentityAccess::RoleRoster.all.each do |rd|
      with_tenant.call do
        role = IdentityAccess::Role.find_or_create_by!(institution_id: institution.id, key: rd.key) do |r|
          r.name = rd.name
          r.description = rd.description
          r.system = rd.system
        end
        IdentityAccess::RoleRoster::PERMISSIONS_BY_ROLE_KEY.fetch(rd.key, []).each do |perm_key|
          permission = IdentityAccess::Permission.find_by(key: perm_key)
          next unless permission
          IdentityAccess::RolePermission.find_or_create_by!(
            institution_id: institution.id, role_id: role.id, permission_id: permission.id
          )
        end
        roles_by_key[rd.key] = role
      end
    end

    # ---- 2) One Core::User per RBAC role, membership + assignment. ----
    staff_rows = IdentityAccess::RoleRoster.all.map do |rd|
      email = "#{rd.key}@colegio-san-jose.test"
      user = Core::User.find_or_create_by!(email: email) do |u|
        u.password = QA_PASSWORD
        u.password_confirmation = QA_PASSWORD
      end
      ensure_password.call(user)

      with_tenant.call do
        membership = Core::InstitutionUser.find_or_create_by!(institution_id: institution.id, user_id: user.id) do |m|
          m.status = "active"
        end
        IdentityAccess::RoleAssignment.find_or_create_by!(
          institution_id: institution.id, institution_user_id: membership.id, role_id: roles_by_key[rd.key].id
        )
      end
      puts "#{rd.key}: #{email}"
      { role: rd.name, key: rd.key, email: email,
        notes: "Asignación RBAC real (#{IdentityAccess::RoleRoster::PERMISSIONS_BY_ROLE_KEY.fetch(rd.key, []).join(', ')})." }
    end

    # ---- 3) Student login: reuse a seeded student that already has legacy
    # guardian records + real grades/enrollments, rather than a new fake row. ----
    student_email = "student@colegio-san-jose.test"
    student_user = Core::User.find_or_create_by!(email: student_email) do |u|
      u.password = QA_PASSWORD
      u.password_confirmation = QA_PASSWORD
    end
    ensure_password.call(student_user)

    student = nil
    guardian_count = nil
    with_tenant.call do
      # Re-runs must reuse whichever student this QA user is already attached
      # to (student.user_id is unique) rather than re-picking a fresh one.
      student = student_user.student ||
        GroupManagement::Student
          .where(institution_id: institution.id, user_id: nil)
          .joins(:student_guardians).distinct.first
      abort "No se encontró un estudiante sembrado con tutor legado para adjuntar login." unless student

      Core::InstitutionUser.find_or_create_by!(institution_id: institution.id, user_id: student_user.id) do |m|
        m.status = "active"
      end
      student.update!(user_id: student_user.id) if student.user_id.nil?
      guardian_count = student.student_guardians.count
    end
    puts "student: #{student_email} (#{student.first_name} #{student.last_name}, #{student.student_code})"

    # ---- 4) Guardian login: Core::GuardianStudent is the ONLY loggable-in
    # guardian link (legacy StudentSupport::Guardian has no user_id). ----
    guardian_email = "guardian@colegio-san-jose.test"
    guardian_user = Core::User.find_or_create_by!(email: guardian_email) do |u|
      u.password = QA_PASSWORD
      u.password_confirmation = QA_PASSWORD
    end
    ensure_password.call(guardian_user)

    with_tenant.call do
      Core::InstitutionUser.find_or_create_by!(institution_id: institution.id, user_id: guardian_user.id) do |m|
        m.status = "active"
      end
      Core::GuardianStudent.find_or_create_by!(
        institution_id: institution.id, guardian_user_id: guardian_user.id, student_id: student.id
      ) { |g| g.relationship = "acudiente" }
    end
    puts "guardian: #{guardian_email} (acudiente de #{student.first_name} #{student.last_name})"

    # ---- 5) Platform admin (super-admin, separate plane — ControlPlane::PlatformAdmin). ----
    platform_admin_email = "platform_admin@edu_platform.test"
    platform_admin = ControlPlane::PlatformAdmin.find_by(email: platform_admin_email)
    if platform_admin
      ensure_password.call(platform_admin)
    else
      platform_admin = ControlPlane::PlatformAdmin.create!(
        email: platform_admin_email, name: "QA Platform Admin", status: "active",
        password: QA_PASSWORD, password_confirmation: QA_PASSWORD
      )
      ControlPlane::Audit.log(action: "platform_admin.bootstrapped", platform_admin: platform_admin, target: platform_admin)
    end
    puts "platform_admin: #{platform_admin_email}"

    # ---- 6) Write the credentials guide. ----
    rows = staff_rows + [
      { role: "Estudiante", key: "student", email: student_email,
        notes: "#{student.first_name} #{student.last_name} (#{student.student_code}), " \
               "#{guardian_count} tutor(es) legado(s) + notas/matrículas reales." },
      { role: "Acudiente", key: "guardian", email: guardian_email,
        notes: "Vinculado (Core::GuardianStudent) a #{student.first_name} #{student.last_name}." },
      { role: "Platform admin (super-admin)", key: "platform_admin", email: platform_admin_email,
        notes: "Plano separado — entra por /control_plane, no por subdominio de institución." }
    ]

    table = +"| Rol | Email | Password | Notas |\n|---|---|---|---|\n"
    rows.each do |r|
      table << "| #{r[:role]} | `#{r[:email]}` | `#{QA_PASSWORD}` | #{r[:notes]} |\n"
    end

    content = <<~MD
      # Credenciales QA — barrido visual por rol

      Generado por `bin/rails qa:seed_role_logins` (re-ejecutable, idempotente).
      Institución: **Colegio San José** (`#{QA_INSTITUTION_SLUG}`), con los ~1500
      estudiantes/notas/docentes ya sembrados por `db/seeds.rb` — estas credenciales
      se adjuntan a datos reales, no a un fixture aislado.

      **URL local (institución):** http://#{QA_INSTITUTION_SLUG}.lvh.me:3000
      (`lvh.me` resuelve por DNS público a 127.0.0.1, no requiere tocar `/etc/hosts`).

      **URL local (super-admin):** http://localhost:3000/control_plane

      ## Flujo de login (dos pasos, obligatorio para TODOS los roles)

      1. Entra con email + password de la tabla.
      2. La app pedirá un código OTP de 6 dígitos por correo — en development
         los correos se escriben a `tmp/mails/` (delivery_method :file, v1.29.0)
         en vez de perderse; abre el archivo más reciente ahí, o para no andar
         buscando en el filesystem corre en otra terminal:

         ```
         bin/rails "qa:otp[<email>]"
         ```

         y pega el código impreso antes de que expire (10 minutos).

      #{table}
      ## Notas

      - RBAC es real: cada rol de staff tiene fila `IdentityAccess::Role` +
        `RoleAssignment` + permisos asociados (no son datos de UI de relleno).
        `institution_users.role` (columna legada) se deja en su default
        `"member"` — no participa en la autorización real.
      - El estudiante y el/la acudiente se adjuntaron a un estudiante YA sembrado
        (con matrículas, notas de mitad de semestre y tutores legados reales),
        para que el barrido visual vea datos end-to-end de una escuela completa.
      - `platform_admin` vive en un plano separado (`ControlPlane::PlatformAdmin`,
        tabla `platform_admins`) — usa su propio login y OTP en `/control_plane`,
        no el subdominio de la institución.
    MD

    File.write(Rails.root.join("tmp/qa_credentials.md"), content)
    puts "\nEscrito tmp/qa_credentials.md"
  end

  desc "Emite e imprime el código OTP (login) para un email QA de institución. " \
       "Uso: bin/rails \"qa:otp[teacher@colegio-san-jose.test]\""
  task :otp, [ :email ] => :environment do |_t, args|
    abort "Uso: bin/rails \"qa:otp[email]\"" unless args[:email].present?

    email = args[:email].to_s.downcase.strip

    if email == "platform_admin@edu_platform.test"
      admin = ControlPlane::PlatformAdmin.find_by(email: email)
      abort "No existe ControlPlane::PlatformAdmin con ese email." unless admin
      issued = ControlPlane::Otp::Issuer.call(platform_admin: admin)
      puts "OTP para #{email}: #{issued.code} (expira #{issued.email_otp.expires_at})"
      next
    end

    institution = Core::Institution.find_by(slug: QA_INSTITUTION_SLUG)
    abort "No existe '#{QA_INSTITUTION_SLUG}'." unless institution

    user = Core::User.find_by(email: email)
    abort "No existe Core::User con ese email." unless user

    issued = nil
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      issued = IdentityAccess::Otp::Issuer.call(user: user, institution: institution, purpose: "login")
    end
    puts "OTP para #{email}: #{issued.code} (expira #{issued.email_otp.expires_at})"
  end
end
