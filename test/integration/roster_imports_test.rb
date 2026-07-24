require "test_helper"

class RosterImportsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { @user, @institution = sign_in_as_member }

  def as_people_manager(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "institution_admin", permission_keys: %w[people.manage],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def within_tenant(&block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(@institution.id)
      block.call
    end
  end

  def ensure_active_term!
    within_tenant do
      Core::AcademicTerm.find_or_create_by!(institution: @institution, code: "2026-1") do |t|
        t.name = "2026-1"
        t.starts_on = Date.new(2026, 1, 1)
        t.ends_on = Date.new(2026, 6, 30)
        t.status = "active"
      end
    end
  end

  def upload(content)
    file = Tempfile.new([ "roster", ".csv" ])
    file.write(content)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "text/csv")
  end

  CSV_HEADER = "national_id,first_name,last_name,gender,birthdate,student_code,entry_year,grade_level,section,email\n"

  test "acceptance: upload -> preview (no writes) -> commit -> real students, idempotent, private" do
    ensure_active_term!

    as_people_manager do
      content = CSV_HEADER +
        "9001,Ana,Pérez,female,2015-03-01,ACC-1,2026,,,\n" \
        "9002,Luis,Gómez,male,2014-05-10,ACC-2,2026,,,\n"

      # Step 1: upload -> enqueue parse + validate, redirect to preview.
      # perform_enqueued_jobs resets the tenant GUC once the job it drains
      # finishes (see ApplicationJob's around_perform), so anything read
      # afterward — even Core::RosterImportBatch.last — must go through
      # within_tenant just like the rest of this test already does.
      perform_enqueued_jobs do
        post "/identity_access/roster_imports", params: { roster_import: { kind: "students", file: upload(content) } }
      end
      batch = within_tenant { Core::RosterImportBatch.last }
      assert_redirected_to identity_access_roster_import_path(batch)
      follow_redirect!
      assert_response :success
      assert_select ".stat__value", text: "2" # total_rows
      assert_no_match(/9001|9002/, response.body) # national_id never shown in full

      assert_equal "validated", within_tenant { batch.reload.status }
      assert_equal 0, within_tenant { GroupManagement::Student.count } # no writes yet

      # Step 2: commit.
      perform_enqueued_jobs do
        post commit_identity_access_roster_import_path(batch)
      end
      assert_redirected_to identity_access_roster_import_path(batch)

      within_tenant do
        assert_equal "committed", batch.reload.status
        assert_equal 2, GroupManagement::Student.count
        assert GroupManagement::Student.exists?(national_id: "9001")
      end

      # Step 3: idempotency — re-commit does not duplicate.
      perform_enqueued_jobs { post commit_identity_access_roster_import_path(batch) }
      within_tenant { assert_equal 2, GroupManagement::Student.count }

      # Step 4: privacy — no plaintext national_id anywhere in roster_import_rows.
      within_tenant do
        batch.roster_import_rows.each do |row|
          assert_not row.raw["national_id"].to_s.include?("9001")
          assert_not row.raw["national_id"].to_s.include?("9002")
        end
      end
    end
  end

  test "mix of create/update/error rows previews correctly without writing anything" do
    ensure_active_term!

    within_tenant do
      GroupManagement::Student.create!(institution: @institution, national_id: "8002",
        first_name: "Ya", last_name: "Existe", gender: "male", birthdate: Date.new(2014, 1, 1),
        student_code: "PRE-EXISTING", entry_year: 2025)
    end

    as_people_manager do
      content = CSV_HEADER +
        "8001,Nuevo,Estudiante,female,2015-01-01,MIX-1,2026,,,\n" +   # create
        "8002,Actualizado,Nombre,male,2014-01-01,PRE-EXISTING,2026,,,\n" + # update
        ",SinDocumento,Prueba,male,2014-01-01,MIX-3,2026,,,\n"        # error

      perform_enqueued_jobs do
        post "/identity_access/roster_imports", params: { roster_import: { kind: "students", file: upload(content) } }
      end
      assert_response :redirect
      follow_redirect!
      assert_response :success

      batch = within_tenant { Core::RosterImportBatch.last }
      within_tenant do
        assert_equal 1, batch.reload.summary["create_count"]
        assert_equal 1, batch.summary["update_count"]
        assert_equal 1, batch.summary["error_count"]
        assert_equal 1, GroupManagement::Student.count # only the pre-existing one — nothing committed yet
      end
    end
  end

  test "an actor without people.manage is denied with a friendly 403" do
    ensure_active_term!

    with_grants do
      get "/identity_access/roster_imports"
      assert_response :forbidden

      post "/identity_access/roster_imports", params: { roster_import: { kind: "students", file: upload(CSV_HEADER) } }
      assert_response :forbidden
    end
  end

  test "index and new render for an actor with people.manage" do
    ensure_active_term!

    as_people_manager do
      get "/identity_access/roster_imports/new"
      assert_response :success

      get "/identity_access/roster_imports"
      assert_response :success
    end
  end

  test "full-async hardening: upload only enqueues, batch waits queued until the job runs" do
    ensure_active_term!

    as_people_manager do
      content = CSV_HEADER + "9101,Ana,Pérez,female,2015-03-01,ASY-1,2026,,,\n"

      assert_enqueued_with(job: Core::RosterImport::ParseAndValidateJob) do
        post "/identity_access/roster_imports", params: { roster_import: { kind: "students", file: upload(content) } }
      end
      assert_redirected_to identity_access_roster_import_path(Core::RosterImportBatch.last)
      follow_redirect!
      assert_response :success
      assert_select ".empty-state__title", text: /Procesando/

      batch = within_tenant { Core::RosterImportBatch.last }
      within_tenant do
        assert_equal "queued", batch.reload.status
        assert_equal 0, batch.roster_import_rows.count
        assert_equal 0, GroupManagement::Student.count
      end

      # The ciphertext column, read straight from the DB, never shows the
      # plaintext CSV — same rigor as the existing row-level privacy check.
      ciphertext = within_tenant do
        ActiveRecord::Base.connection.select_value(
          "SELECT pending_content FROM roster_import_batches WHERE id = #{ActiveRecord::Base.connection.quote(batch.id)}"
        )
      end
      assert_not_nil ciphertext
      assert_not ciphertext.include?("9101")
      assert_not ciphertext.include?("Ana")

      perform_enqueued_jobs

      within_tenant do
        assert_equal "validated", batch.reload.status
        assert_equal 1, batch.roster_import_rows.count
        assert_nil batch.pending_content
      end
    end
  end
end
