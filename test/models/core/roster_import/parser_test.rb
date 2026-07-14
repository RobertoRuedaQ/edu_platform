require "test_helper"

class Core::RosterImport::ParserTest < ActiveSupport::TestCase
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_institution
    slug = "ri-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_batch(institution)
    term = Core::AcademicTerm.create!(institution: institution, code: "2026-1", name: "2026-1",
      starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
    Core::RosterImportBatch.create!(institution: institution, academic_term: term, kind: "students")
  end

  CSV_HEADER = "national_id,first_name,last_name,gender,birthdate,student_code,entry_year,grade_level,section,email\n"

  test "parses one RosterImportRow per data line" do
    institution = build_institution

    within_tenant(institution) do
      batch = build_batch(institution)
      content = CSV_HEADER +
        "1001,Ana,Pérez,female,2015-03-01,COD-1,2026,,,\n" \
        "1002,Luis,Gómez,male,2014-05-10,COD-2,2026,,,\n"

      result = Core::RosterImport::Parser.call(batch: batch, content: content)

      assert_equal 2, result.row_count
      assert_equal 2, batch.roster_import_rows.count
      assert_equal [ 1, 2 ], batch.roster_import_rows.order(:line_number).pluck(:line_number)
    end
  end

  test "ignores unknown extra columns and tolerates missing optional ones" do
    institution = build_institution

    within_tenant(institution) do
      batch = build_batch(institution)
      content = "national_id,first_name,last_name,gender,birthdate,student_code,unexpected_column\n" \
                "1001,Ana,Pérez,female,2015-03-01,COD-1,algo\n"

      Core::RosterImport::Parser.call(batch: batch, content: content)

      row = batch.roster_import_rows.first
      assert_equal "Ana", row.raw["first_name"]
      assert_nil row.raw["unexpected_column"]
      assert_nil row.raw["grade_level"]
    end
  end

  test "encrypts national_id — the plaintext never reaches the row" do
    institution = build_institution

    within_tenant(institution) do
      batch = build_batch(institution)
      content = CSV_HEADER + "1234567890,Ana,Pérez,female,2015-03-01,COD-1,2026,,,\n"

      Core::RosterImport::Parser.call(batch: batch, content: content)

      row = batch.roster_import_rows.first
      assert_not_equal "1234567890", row.raw["national_id"]
      assert_equal "1234567890", Core::RosterImport::Cipher.decrypt(row.raw["national_id"])
      # Belt-and-suspenders: the ciphertext blob itself never contains the plaintext.
      assert_not row.raw["national_id"].include?("1234567890")
    end
  end

  test "sets the batch to uploaded with the total row count" do
    institution = build_institution

    within_tenant(institution) do
      batch = build_batch(institution)
      content = CSV_HEADER + "1001,Ana,Pérez,female,2015-03-01,COD-1,2026,,,\n"

      Core::RosterImport::Parser.call(batch: batch, content: content)

      assert_equal "uploaded", batch.reload.status
      assert_equal 1, batch.summary["total_rows"]
    end
  end

  test "makes zero writes to students" do
    institution = build_institution

    within_tenant(institution) do
      batch = build_batch(institution)
      content = CSV_HEADER + "1001,Ana,Pérez,female,2015-03-01,COD-1,2026,,,\n"

      Core::RosterImport::Parser.call(batch: batch, content: content)

      assert_equal 0, GroupManagement::Student.count
    end
  end
end
