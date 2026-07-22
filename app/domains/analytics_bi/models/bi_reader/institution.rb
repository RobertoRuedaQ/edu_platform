module AnalyticsBi
  module BiReader
    # Read-only view of Core::Institution through the edu_bi_reader
    # connection — a SEPARATE class, never Core::Institution itself (that
    # class is bound to the primary edu_app_runtime pool). institutions has
    # no RLS anyway (GLOBAL table), so BYPASSRLS adds nothing here — reading
    # it through this connection is purely for a single consistent
    # connection across the whole cross-tenant report, not a security need.
    class Institution < BiReaderRecord
      self.table_name = "institutions"
    end
  end
end
