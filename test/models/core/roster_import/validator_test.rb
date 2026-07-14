require "test_helper"

class Core::RosterImport::ValidatorTest < ActiveSupport::TestCase
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_institution
    slug = "riv-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_batch(institution)
    term = Core::AcademicTerm.create!(institution: institution, code: "2026-1", name: "2026-1",
      starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
    Core::RosterImportBatch.create!(institution: institution, academic_term: term, kind: "students")
  end

  def parse(institution, batch, content)
    Core::RosterImport::Parser.call(batch: batch, content: content)
  end

  CSV_HEADER = "national_id,first_name,last_name,gender,birthdate,student_code,entry_year,grade_level,section,email\n"

  test "a brand-new national_id is marked valid (will create)" do
    institution = build_institution

    within_tenant(institution) do
      batch = build_batch(institution)
      parse(institution, batch, CSV_HEADER + "1001,Ana,Pérez,female,2015-03-01,COD-1,2026,,,\n")

      Core::RosterImport::Validator.call(batch: batch)

      assert_equal "valid", batch.roster_import_rows.first.status
    end
  end

  test "a national_id matching an existing student is marked duplicate (will update)" do
    institution = build_institution

    within_tenant(institution) do
      GroupManagement::Student.create!(institution: institution, national_id: "1001",
        first_name: "Ana", last_name: "Pérez", gender: "female", birthdate: Date.new(2015, 3, 1),
        student_code: "EXISTING-1", entry_year: 2025)

      batch = build_batch(institution)
      parse(institution, batch, CSV_HEADER + "1001,Ana,Pérez,female,2015-03-01,COD-1,2026,,,\n")

      Core::RosterImport::Validator.call(batch: batch)

      assert_equal "duplicate", batch.roster_import_rows.first.status
    end
  end

  test "a missing required field is marked error" do
    institution = build_institution

    within_tenant(institution) do
      batch = build_batch(institution)
      parse(institution, batch, CSV_HEADER + ",Ana,Pérez,female,2015-03-01,COD-1,2026,,,\n") # no national_id

      Core::RosterImport::Validator.call(batch: batch)

      row = batch.roster_import_rows.first
      assert_equal "error", row.status
      assert_match(/national_id/, row.message)
    end
  end

  test "a grade_level reference that doesn't exist is marked error" do
    institution = build_institution

    within_tenant(institution) do
      batch = build_batch(institution)
      parse(institution, batch, CSV_HEADER + "1001,Ana,Pérez,female,2015-03-01,COD-1,2026,Grado 99,,\n")

      Core::RosterImport::Validator.call(batch: batch)

      row = batch.roster_import_rows.first
      assert_equal "error", row.status
      assert_match(/grade_level/, row.message)
    end
  end

  test "a grade_level/section that DO exist resolve without error" do
    institution = build_institution

    within_tenant(institution) do
      grade = GroupManagement::GradeLevel.create!(institution: institution, name: "Grado 9", level_number: 9)
      GroupManagement::Section.create!(institution: institution, grade_level: grade, name: "9A", academic_year: 2026)

      batch = build_batch(institution)
      parse(institution, batch, CSV_HEADER + "1001,Ana,Pérez,female,2015-03-01,COD-1,2026,Grado 9,9A,\n")

      Core::RosterImport::Validator.call(batch: batch)

      assert_equal "valid", batch.roster_import_rows.first.status
    end
  end

  test "two rows sharing the same national_id within the same file are marked collision" do
    institution = build_institution

    within_tenant(institution) do
      batch = build_batch(institution)
      content = CSV_HEADER +
        "1001,Ana,Pérez,female,2015-03-01,COD-1,2026,,,\n" \
        "1001,Ana,OtraPersona,female,2015-03-01,COD-2,2026,,,\n"
      parse(institution, batch, content)

      Core::RosterImport::Validator.call(batch: batch)

      statuses = batch.roster_import_rows.order(:line_number).pluck(:status)
      assert_equal %w[collision collision], statuses
    end
  end

  test "makes zero writes to students" do
    institution = build_institution

    within_tenant(institution) do
      batch = build_batch(institution)
      parse(institution, batch, CSV_HEADER + "1001,Ana,Pérez,female,2015-03-01,COD-1,2026,,,\n")

      Core::RosterImport::Validator.call(batch: batch)

      assert_equal 0, GroupManagement::Student.count
    end
  end

  test "sets the batch to validated with correct counters for a realistic mix" do
    institution = build_institution

    within_tenant(institution) do
      GroupManagement::Student.create!(institution: institution, national_id: "2002",
        first_name: "Existente", last_name: "Prueba", gender: "male", birthdate: Date.new(2014, 1, 1),
        student_code: "EXISTING-2", entry_year: 2025)

      batch = build_batch(institution)
      content = CSV_HEADER +
        "1001,Ana,Pérez,female,2015-03-01,COD-1,2026,,,\n" +      # valid
        "2002,Luis,Gómez,male,2014-01-01,COD-2,2026,,,\n" +       # duplicate
        ",FaltaId,Prueba,male,2014-01-01,COD-3,2026,,,\n"         # error
      parse(institution, batch, content)

      Core::RosterImport::Validator.call(batch: batch)

      batch.reload
      assert_equal "validated", batch.status
      assert_equal 1, batch.summary["create_count"]
      assert_equal 1, batch.summary["update_count"]
      assert_equal 1, batch.summary["error_count"]
      assert_equal 0, batch.summary["collision_count"]
      assert_equal 3, batch.summary["total_rows"]
    end
  end
end
