# Solid Queue workers run in separate processes with NO request context, so the
# tenant must ride along with the job: captured on enqueue, re-established
# (Current + GUC, inside a transaction) before the job body runs any query.
class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  attr_accessor :institution_id

  # Snapshot the tenant at enqueue time.
  def serialize
    super.merge("institution_id" => institution_id || Current.institution_id)
  end

  def deserialize(job_data)
    super
    self.institution_id = job_data["institution_id"]
  end

  around_perform do |job, block|
    if job.institution_id
      Current.set(institution_id: job.institution_id) do
        ActiveRecord::Base.transaction do
          Tenant::Guc.set_local(job.institution_id)
          block.call
        end
      end
    else
      # Global/maintenance job with no tenant — runs with no GUC on purpose.
      block.call
    end
  end
end
