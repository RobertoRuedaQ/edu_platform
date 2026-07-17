module AnalyticsBi
  module BiReader
    # Read-only, CROSS-TENANT view of GroupManagement::Student via
    # edu_bi_reader (BYPASSRLS) — every query MUST group/filter by
    # institution_id explicitly (BI_DOCUMENT.md §6.1: the app-level filter is
    # the ONLY defense once RLS is bypassed, never optional). Never exposed
    # row-by-row outside this domain's aggregation query objects.
    class Student < BiReaderRecord
      self.table_name = "students"
    end
  end
end
