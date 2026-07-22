module Library
  # Physical copies of one title — nested under the resource, no destroy
  # action (copies are status-transitioned to lost/maintenance, never
  # destroyed — see the migration's comment on why copy_id is RESTRICT-safe).
  class ResourceCopiesController < ApplicationController
    before_action :set_resource

    def index
      authorize!("library.catalog.manage")
      @copies = @resource.copies.order(:barcode)
    end

    def new
      authorize!("library.catalog.manage")
      @copy = @resource.copies.new
    end

    def create
      authorize!("library.catalog.manage")
      @copy = @resource.copies.new(copy_params.merge(institution: Current.institution))
      if @copy.save
        redirect_to library_resource_copies_path(@resource), notice: "Ejemplar agregado."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # "loaned" is deliberately rejected here — that transition ONLY happens
    # via Library::LoanRecorder (lock + idempotent + real Loan row), never a
    # bare status edit from the catalog screen (a copy marked "loaned" with
    # no Loan row would break every read that assumes the two agree).
    def update
      authorize!("library.catalog.manage")
      @copy = @resource.copies.find(params[:id])
      if copy_params[:status] == "loaned"
        redirect_to library_resource_copies_path(@resource),
          alert: "El estado 'loaned' solo se asigna al prestar un ejemplar desde el mostrador."
        return
      end

      if @copy.update(copy_params)
        redirect_to library_resource_copies_path(@resource), notice: "Ejemplar actualizado."
      else
        redirect_to library_resource_copies_path(@resource), alert: @copy.errors.full_messages.to_sentence
      end
    end

    private

    def set_resource
      @resource = Library::Resource.find_by!(institution_id: Current.institution_id, id: params[:resource_id])
    end

    def copy_params
      params.require(:resource_copy).permit(:barcode, :status)
    end
  end
end
