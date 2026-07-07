# Owned by app/domains/teacher_management. Departamentos se alcanza desde
# dentro de este dominio (link en teachers#index/#show), no como entrada propia
# de nav — evita saturar la barra con una segunda entrada para el mismo dominio.
Navigation::Registry.register(
  domain: "teacher_management",
  label: "Docentes",
  path: "/teacher_management/teachers",
  permission: "teachers.view",
  position: 35
)
