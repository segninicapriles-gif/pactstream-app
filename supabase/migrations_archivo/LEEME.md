# Migraciones archivadas (hasta el 28-oct-2026)

Historia de PactStream hasta la línea base `supabase/migrations/20261028230000_linea_base_dev.sql`.
**No se aplican**: la CLI de Supabase solo lee `supabase/migrations/`.

Se archivaron porque no reproducían la base de dev (`erqglsrnknhwqhfupckf`):
`organizations` definida dos veces (`legal_name`/`cif` frente a `name`/`vat_id`),
21 funciones cambiadas a mano en dev o sin fichero, migraciones aplicadas fuera de
orden y dos seeds de demo que chocaban entre sí. La línea base es un volcado de dev
verificado con `supabase db diff --linked` («No schema changes found»).

En dev, estas versiones constan como `reverted` en `supabase_migrations.schema_migrations`;
la tabla original se guardó en `supabase_migrations.schema_migrations_backup_20261028`.
Los ficheros se conservan sin modificar.
