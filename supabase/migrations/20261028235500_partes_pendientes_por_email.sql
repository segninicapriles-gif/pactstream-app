-- 20261028235500_partes_pendientes_por_email.sql
-- Invitar a una parte que aún no tiene cuenta.
--
-- sf_invite_party está diseñada para eso («si el email tiene cuenta PactStream,
-- vincula; si no, queda pendiente») y al registrarse el usuario un trigger
-- enlaza las partes pendientes por snapshot_email (UPDATE pact_parties SET
-- user_id = NEW.id WHERE user_id IS NULL AND snapshot_email = email). Pero la
-- restricción pact_parties_user_or_org del esquema inicial exigía user_id u
-- organization_id, así que toda invitación a un email sin cuenta fallaba: en el
-- asistente de nueva obra y al aceptar un presupuesto de CostPact.
--
-- Ahora una parte puede estar pendiente si tiene email al que invitar.

alter table public.pact_parties drop constraint if exists pact_parties_user_or_org;
alter table public.pact_parties add constraint pact_parties_user_or_org check (
  user_id is not null
  or organization_id is not null
  or nullif(trim(snapshot_email), '') is not null
);
