module AnalyticsBi
  # STUB KPIs for the actor's OWN tenant. No aggregate/materialized view
  # exists yet — real numbers land once one does.
  # TODO: reemplazar por vista materializada / agregado real (institution-scoped).
  module InstitutionDashboard
    def self.stub
      {
        total_students: 187,
        avg_grade: 3.8,
        attendance_rate: 94.2,
        enrollment_trend: [
          { label: "Feb", value: 180 }, { label: "Mar", value: 182 }, { label: "Abr", value: 184 },
          { label: "May", value: 185 }, { label: "Jun", value: 186 }, { label: "Jul", value: 187 }
        ],
        grades_by_subject: [
          { label: "Álgebra", value: 3.6 }, { label: "Historia", value: 4.0 },
          { label: "Cálculo", value: 3.4 }, { label: "Sociología", value: 4.1 }
        ],
        status_breakdown: [
          { label: "Activos", value: 178 }, { label: "En licencia", value: 5 }, { label: "Inactivos", value: 4 }
        ]
      }
    end
  end
end
