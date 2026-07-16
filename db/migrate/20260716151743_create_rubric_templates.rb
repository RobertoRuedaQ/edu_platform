class CreateRubricTemplates < ActiveRecord::Migration[8.1]
  # assignments (v1.26.0, slice 4: rúbricas). The reusable LIBRARY —
  # author-owned, tenant-scoped, RLS ENABLE+FORCE like every other
  # tenant-owned table. Editable freely: a task that used a template
  # freezes its own immutable snapshot at publish time (see the next
  # migration), so editing the live library here can never corrupt
  # something already graded — same reasoning as
  # ControlPlane::Subscription's price_tiers_snapshot/ReportCards'
  # lines_snapshot.
  def change
    create_table :rubric_templates, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      # Author-owned visibility (this slice) — the docente who created it
      # is the only one who sees/uses it. "Share with department" is an
      # explicit future decision, not built here.
      t.references :authored_by_user, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :users, on_delete: :cascade }
      t.string :name, null: false

      t.timestamps
    end
    add_index :rubric_templates, %i[institution_id authored_by_user_id],
      name: "idx_rubric_templates_on_institution_author"
    enable_rls :rubric_templates

    create_table :rubric_criteria, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :rubric_template, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      # Relative weight — the calculation is a RATIO (§4), so criteria
      # never need to sum to 100.
      t.decimal :weight, precision: 6, scale: 2, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :rubric_criteria, %i[institution_id rubric_template_id],
      name: "idx_rubric_criteria_on_institution_template"
    enable_rls :rubric_criteria

    # Levels are columns of the SAME matrix shared by every criterion in a
    # template (e.g. Incompleto/Básico/Bueno/Excelente) — never per-criterion.
    create_table :rubric_levels, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :rubric_template, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.string :label, null: false
      t.decimal :points, precision: 6, scale: 2, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :rubric_levels, %i[institution_id rubric_template_id],
      name: "idx_rubric_levels_on_institution_template"
    enable_rls :rubric_levels

    # The "what distinguishes Bueno from Excelente" text — optional, one
    # per (criterion, level) cell of the matrix.
    create_table :rubric_cell_descriptors, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :rubric_criterion, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :rubric_criteria, on_delete: :cascade }
      t.references :rubric_level, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.text :descriptor

      t.timestamps
    end
    add_index :rubric_cell_descriptors, %i[rubric_criterion_id rubric_level_id], unique: true,
      name: "idx_rubric_cell_descriptors_unique_cell"
    add_index :rubric_cell_descriptors, :institution_id, name: "idx_rubric_cell_descriptors_on_institution"
    enable_rls :rubric_cell_descriptors
  end
end
