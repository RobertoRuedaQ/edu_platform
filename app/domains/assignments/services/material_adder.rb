module Assignments
  # Adds ONE file to an Assignment's own materials — the teacher's sibling
  # of Assignments::AttachmentAdder (entrega, v1.24.0): same real
  # content-type/size rules (Assignments::AttachmentTypeCheck), different
  # owner, different cap, and — the actual difference — this is never
  # called from a portal write; the controller's own authorize! is the
  # gate, not a relation scope. Allowed while draft or published; blocked
  # once archived (same "archived = frozen" principle as v1.24.0). Adding
  # a material after publishing is normal and expected — not a frozen
  # snapshot like report_cards.
  class MaterialAdder
    MAX_MATERIALS = 10

    Result = Data.define(:material, :error)

    def self.call(assignment:, file:, attached_by:)
      new(assignment: assignment, file: file, attached_by: attached_by).call
    end

    def initialize(assignment:, file:, attached_by:)
      @assignment = assignment
      @file = file
      @attached_by = attached_by
    end

    def call
      return Result.new(material: nil, error: :assignment_closed) if assignment.archived?
      return Result.new(material: nil, error: :no_file) if file.blank?
      return Result.new(material: nil, error: :too_many) if assignment.materials.count >= MAX_MATERIALS
      return Result.new(material: nil, error: :too_large) if Assignments::AttachmentTypeCheck.too_large?(file)

      material = assignment.materials.create!(institution: assignment.institution, attached_by: attached_by)
      material.file.attach(file)

      error = Assignments::AttachmentTypeCheck.reject_if_invalid_type!(material)
      return Result.new(material: nil, error: error) if error

      Result.new(material: material, error: nil)
    end

    private

    attr_reader :assignment, :file, :attached_by
  end
end
