module Admissions
  # Convierte una solicitud aceptada en un estudiante matriculado real — su
  # propio endpoint auditable (molde library's checkouts/returns split: una
  # acción de negocio con efectos reales merece su propia ruta, nunca un
  # PATCH genérico de ApplicationsController#update).
  class ApplicationAcceptancesController < ApplicationController
    def create
      authorize!("admissions.applications.manage")
      application = Admissions::Application.find_by!(institution_id: Current.institution_id,
        id: params[:application_id])

      student = Admissions::AcceptanceConverter.call(institution: Current.institution, application: application,
        student_code: params[:student_code], decided_by: Current.institution_user)
      redirect_to admissions_application_path(application),
        notice: "Solicitud aceptada — estudiante #{student.student_code} matriculado."
    rescue Admissions::AcceptanceConverter::NotReviewable
      redirect_to admissions_application_path(application), alert: "La solicitud ya fue decidida."
    end
  end
end
