require "test_helper"

class Library::ResourceCopyTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "lrc-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  test "status is restricted to the closed vocabulary even bypassing app validation (DB CHECK)" do
    institution = build_institution
    within_tenant(institution) do
      resource = Library::Resource.create!(institution: institution, title: "Cien años de soledad")
      copy = Library::ResourceCopy.new(institution: institution, resource: resource, barcode: "LIB-1",
        status: "bogus")

      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) { copy.save!(validate: false) }
      end
    end
  end

  test "barcode is unique per institution — friendly validation error, never a raw DB exception" do
    institution = build_institution
    within_tenant(institution) do
      resource = Library::Resource.create!(institution: institution, title: "Cien años de soledad")
      Library::ResourceCopy.create!(institution: institution, resource: resource, barcode: "LIB-1")
      duplicate = Library::ResourceCopy.new(institution: institution, resource: resource, barcode: "LIB-1")

      assert_not duplicate.valid?
      assert duplicate.errors[:barcode].any?
    end
  end

  test "barcode uniqueness is ALSO enforced at the DB level, bypassing app validation" do
    institution = build_institution
    within_tenant(institution) do
      resource = Library::Resource.create!(institution: institution, title: "Cien años de soledad")
      Library::ResourceCopy.create!(institution: institution, resource: resource, barcode: "LIB-1")
      duplicate = Library::ResourceCopy.new(institution: institution, resource: resource, barcode: "LIB-1")

      assert_raises(ActiveRecord::RecordNotUnique) do
        ActiveRecord::Base.transaction(requires_new: true) { duplicate.save!(validate: false) }
      end
    end
  end
end
