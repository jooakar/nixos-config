# Databases on the host, one per cluster service. Each name here gets its own
# database, a role of the same name that owns it, and a password read from
# secrets/pg-<name>.age. Nothing else may connect to that database.
[
  "hundred"
]
