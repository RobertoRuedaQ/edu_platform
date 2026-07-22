module Library
  # Catalog curation — no Query object (institution-wide, nothing to filter
  # per row, molde Cafeteria::MenuController).
  class ResourcesController < ApplicationController
    before_action :set_resource, only: %i[edit update]

    def index
      authorize!("library.catalog.manage")
      @resources = Library::Resource.where(institution_id: Current.institution_id).order(:title)
    end

    def new
      authorize!("library.catalog.manage")
      @resource = Library::Resource.new
    end

    def create
      authorize!("library.catalog.manage")
      @resource = Library::Resource.new(resource_params.merge(institution: Current.institution))
      if @resource.save
        redirect_to library_resources_path, notice: "Título creado."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize!("library.catalog.manage")
    end

    def update
      authorize!("library.catalog.manage")
      if @resource.update(resource_params)
        redirect_to library_resources_path, notice: "Título actualizado."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_resource
      @resource = Library::Resource.find_by!(institution_id: Current.institution_id, id: params[:id])
    end

    def resource_params
      params.require(:resource).permit(:title, :author, :publisher, :isbn, :dewey_category)
    end
  end
end
