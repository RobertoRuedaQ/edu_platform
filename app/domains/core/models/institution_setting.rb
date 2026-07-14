module Core
  # TENANT-SCOPED 1:1 settings row. RLS-enforced. Inserted by
  # Provisioning::CreateInstitution under SET LOCAL so WITH CHECK passes.
  class InstitutionSetting < ApplicationRecord
    self.table_name = "institution_settings"

    belongs_to :institution, class_name: "Core::Institution", inverse_of: :settings
  end
end
