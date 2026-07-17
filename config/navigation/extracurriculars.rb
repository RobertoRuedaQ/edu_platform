# Owned by app/domains/extracurriculars. La tile aterriza en el catálogo con
# el scope propio del actor (Extracurriculars::ActivityScope): el coordinador
# ve todas, el instructor solo las suyas.
#
# El registro admite UN permiso por tile. Se gatea por `activity.instruct` —
# la capacidad BASE de acceso a la superficie que AMBOS roles tienen: el rol
# activity_coordinator se siembra con activity.manage Y activity.instruct
# (manage es el superset institución-wide para escribir el catálogo e inscribir
# en cualquier actividad; instruct es el piso "acceder al panel"). Así una sola
# tile sirve a ambos sin duplicarla ni tocar el mecanismo del Registry.
Navigation::Registry.register(
  domain: "extracurriculars",
  label: "Extracurriculares",
  path: "/extracurriculars/activities",
  permission: "activity.instruct",
  position: 28
)
