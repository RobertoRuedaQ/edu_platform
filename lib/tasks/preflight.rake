# Pre-vuelo de base de datos: valida que TODO esté correctamente configurado
# antes de sembrar (db:seed). Es de solo lectura y puede correr como cualquier
# rol. Falla con código de salida != 0 si algún chequeo no cumple.
#
#   bin/rails db:preflight
namespace :db do
  desc "Valida roles, RLS, migraciones y privilegios antes de correr el seed"
  task preflight: :environment do
    conn = ActiveRecord::Base.connection

    # --- expectativas declaradas -------------------------------------------
    EXPECTED_ROLES = {
      "edu_migrator"    => { super: false, bypassrls: false, createdb: true,  login: true },
      "edu_app_runtime" => { super: false, bypassrls: false, createdb: false, login: true },
      "edu_bi_reader"   => { super: false, bypassrls: true,  createdb: false, login: true }
    }.freeze
    EXPECTED_DATABASES = %w[
      edu_platform_development edu_platform_development_cache
      edu_platform_development_queue edu_platform_development_cable
      edu_platform_test
    ].freeze
    # Tablas globales / de infraestructura que NO deben tener RLS de inquilino.
    GLOBAL_ALLOWLIST = %w[institutions users sessions schema_migrations ar_internal_metadata].freeze
    SOLID_PREFIXES   = %w[solid_queue_ solid_cache_ solid_cable_].freeze
    GUC              = "app.current_institution_id".freeze

    failures = []
    def line(ok, label, detail = nil)
      icon = ok ? "\e[32m✅\e[0m" : "\e[31m❌\e[0m"
      puts "  #{icon} #{label}#{detail ? " — #{detail}" : ''}"
    end

    def to_bool(v) = ActiveModel::Type::Boolean.new.cast(v)

    def tenant_tables(conn, allow, prefixes)
      conn.select_values(<<~SQL).reject { |t| allow.include?(t) || prefixes.any? { |p| t.start_with?(p) } }
        SELECT c.relname
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname = 'institution_id' AND a.attnum > 0 AND NOT a.attisdropped
        WHERE n.nspname = 'public' AND c.relkind = 'r'
      SQL
    end

    puts "\n\e[1mPRE-VUELO edu_platform\e[0m  (#{Rails.env})"
    puts "Conectado como: #{conn.select_value('SELECT current_user')} | BD: #{conn.current_database}"
    puts "PostgreSQL: #{conn.select_value('SHOW server_version').split.first} | Rails: #{Rails.version} | Ruby: #{RUBY_VERSION}"

    # 1) ROLES ---------------------------------------------------------------
    puts "\n1) Roles de base de datos"
    rows = conn.select_all(
      "SELECT rolname, rolsuper, rolbypassrls, rolcreatedb, rolcanlogin FROM pg_roles WHERE rolname LIKE 'edu_%'"
    ).to_a.index_by { |r| r["rolname"] }
    EXPECTED_ROLES.each do |name, exp|
      r = rows[name]
      if r.nil?
        failures << "rol #{name} no existe"
        line(false, name, "no existe")
        next
      end
      got = { super: to_bool(r["rolsuper"]), bypassrls: to_bool(r["rolbypassrls"]),
              createdb: to_bool(r["rolcreatedb"]), login: to_bool(r["rolcanlogin"]) }
      ok = got == exp
      failures << "rol #{name}: esperado #{exp}, obtenido #{got}" unless ok
      line(ok, name, "super=#{got[:super]} bypassrls=#{got[:bypassrls]} createdb=#{got[:createdb]} login=#{got[:login]}")
    end

    # 2) BASES DE DATOS ------------------------------------------------------
    puts "\n2) Bases de datos"
    existing = conn.select_values("SELECT datname FROM pg_database WHERE datname LIKE 'edu_platform%'")
    EXPECTED_DATABASES.each do |db|
      ok = existing.include?(db)
      failures << "falta base #{db}" unless ok
      line(ok, db)
    end

    # 3) MIGRACIONES ---------------------------------------------------------
    puts "\n3) Migraciones (primary)"
    files   = Dir[Rails.root.join("db/migrate/*.rb")].map { |f| File.basename(f).split("_").first }.sort
    applied = conn.select_values("SELECT version FROM schema_migrations")
    pending = files - applied
    ok = pending.empty?
    failures << "migraciones pendientes: #{pending.join(', ')}" unless ok
    line(ok, "#{applied.size} aplicadas, #{pending.size} pendientes",
         ok ? "todas al día" : "pendientes: #{pending.join(', ')}")

    # 4) RLS: ENABLE + FORCE en toda tabla de inquilino ----------------------
    puts "\n4) RLS (ENABLE + FORCE) en tablas de inquilino"
    tables = tenant_tables(conn, GLOBAL_ALLOWLIST, SOLID_PREFIXES).sort
    flags = conn.select_all(<<~SQL).to_a.index_by { |r| r["relname"] }
      SELECT c.relname, c.relrowsecurity, c.relforcerowsecurity
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relkind = 'r'
    SQL
    missing_rls = tables.reject { |t| to_bool(flags[t]["relrowsecurity"]) && to_bool(flags[t]["relforcerowsecurity"]) }
    ok = missing_rls.empty?
    failures << "sin FORCE RLS: #{missing_rls.join(', ')}" unless ok
    line(ok, "#{tables.size} tablas de inquilino con FORCE RLS",
         ok ? "OK" : "faltan: #{missing_rls.join(', ')}")

    # 5) Índice líder por institution_id -------------------------------------
    puts "\n5) Índice cuyo primer campo es institution_id"
    no_index = tables.reject do |t|
      conn.select_value(<<~SQL).to_i.positive?
        SELECT count(*) FROM pg_index i
        JOIN pg_class tb ON tb.oid = i.indrelid
        JOIN pg_namespace n ON n.oid = tb.relnamespace
        JOIN pg_attribute a ON a.attrelid = tb.oid AND a.attnum = i.indkey[0]
        WHERE n.nspname = 'public' AND tb.relname = #{conn.quote(t)} AND a.attname = 'institution_id'
      SQL
    end
    ok = no_index.empty?
    failures << "sin índice líder institution_id: #{no_index.join(', ')}" unless ok
    line(ok, "índice líder presente en las #{tables.size} tablas",
         ok ? "OK" : "faltan: #{no_index.join(', ')}")

    # 6) Predicado endurecido: sin inquilino / GUC vacío => 0 filas, sin error
    puts "\n6) Aislamiento sin inquilino (predicado NULLIF)"
    probe = tables.include?("institution_settings") ? "institution_settings" : tables.first
    if probe
      begin
        conn.transaction(requires_new: true) do
          conn.execute("SELECT set_config('#{GUC}', '', true)")   # simula GUC vacío
          n = conn.select_value("SELECT count(*) FROM #{conn.quote_table_name(probe)}").to_i
          ok = n.zero?
          failures << "#{probe} con GUC vacío devolvió #{n} (esperado 0)" unless ok
          line(ok, "GUC vacío sobre #{probe} => #{n} filas (sin error)")
          raise ActiveRecord::Rollback
        end
      rescue ActiveRecord::StatementInvalid => e
        failures << "predicado RLS lanza error con GUC vacío: #{e.message.lines.first.strip}"
        line(false, "GUC vacío sobre #{probe}", "LANZA ERROR (falta NULLIF)")
      end
    else
      line(false, "no hay tablas de inquilino para probar")
      failures << "no hay tablas de inquilino"
    end

    # 7) Privilegios de edu_app_runtime (rol del seed) -----------------------
    puts "\n7) Privilegios DML de edu_app_runtime"
    checks = [%w[institutions INSERT], %w[institutions SELECT]]
    checks += [%w[students INSERT], %w[students SELECT]] if tables.include?("students")
    checks.each do |tbl, priv|
      granted = to_bool(conn.select_value(
        "SELECT has_table_privilege('edu_app_runtime', #{conn.quote(tbl)}, #{conn.quote(priv)})"
      ))
      failures << "edu_app_runtime sin #{priv} en #{tbl}" unless granted
      line(granted, "#{priv} en #{tbl}")
    end

    # --- veredicto ----------------------------------------------------------
    puts
    if failures.empty?
      puts "\e[32m\e[1mPRE-VUELO OK\e[0m — todo listo. Corre el seed con:"
      puts "  EDU_DB_USER=edu_app_runtime EDU_DB_PASSWORD=$EDU_APP_RUNTIME_PASSWORD bin/rails runner \"Rails.application.load_seed\""
    else
      puts "\e[31m\e[1mPRE-VUELO FALLIDO\e[0m (#{failures.size}):"
      failures.each { |f| puts "  - #{f}" }
      abort("\nCorrige lo anterior antes de sembrar.")
    end
  end
end
