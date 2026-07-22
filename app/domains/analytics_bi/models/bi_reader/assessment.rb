module AnalyticsBi
  module BiReader
    # Read-only, CROSS-TENANT view of Schedules::Assessment via edu_bi_reader
    # (BYPASSRLS) — same discipline as BiReader::Student: every query groups/
    # filters by institution_id explicitly, never a bare ungrouped average
    # that would blend every tenant's grades into one number.
    class Assessment < BiReaderRecord
      self.table_name = "assessments"
    end
  end
end
