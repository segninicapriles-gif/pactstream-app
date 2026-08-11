-- ─── Dónde viven los papeles del expediente CAE, y quién los ve ──────────────
--
-- ✅ APLICADA el 10-ago-2026 con el sello 20260810163044.
--
-- Comprobado tras aplicarla: los 9 documentos de PACTO que había siguen sin
-- encajar con el patrón de ruta CAE, luego siguen invisibles para el rol
-- `authenticated`, igual que antes. Esta migración solo abre la puerta del
-- vertical CAE.
--
-- Por qué hace falta y no bastaba con la de T2 (`20260810124108`):
--
--   · `public.documents` tenía RLS ACTIVADA y CERO políticas. Eso no es «abierto
--     por descuido», es lo contrario: nadie con el rol `authenticated` podía leer
--     ni escribir una sola fila. Las 9 filas que hay son semilla, escritas con la
--     clave de servicio. Sin políticas, la subida de T5 no tiene por dónde entrar.
--   · No existía ningún cubo de Storage donde dejar el fichero: solo estaban
--     `milestone-evidences` (evidencia de hitos de un pacto) y `avatars`.
--
-- La decisión de diseño que sostiene lo de abajo: **el dueño de un documento CAE
-- se deduce de su ruta**. `documents` no tiene `organization_id` y añadírsela
-- sería tocar una tabla de producción de la que cuelga todo el pacto. En vez de
-- eso, la ruta se fija por convención —`cae-documentos/<organización>/<expediente>/…`—
-- y la política la lee. Si la ruta no encaja con el patrón, la función devuelve
-- NULL, `fn_is_org_active_member(NULL)` devuelve false y la fila queda fuera:
-- deny-by-default sin excepciones que recordar.
--
-- Consecuencia buscada: estas políticas NO tocan los documentos de pacto. Un
-- documento con `pact_id` sigue sin ser visible para `authenticated`, igual que
-- antes de esta migración. Aquí solo se abre la puerta del vertical CAE.
--
-- Esta migración solo AÑADE: un cubo, una función y seis políticas nuevas. No
-- borra ni modifica nada de lo que ya había.

-- ─── El cubo ─────────────────────────────────────────────────────────────────
-- Privado. Mismos límites que `milestone-evidences` (20 MB) porque el material
-- es el mismo: fotos de obra hechas con un móvil y PDF escaneados. Se añade HEIC
-- porque es lo que sale por defecto de un iPhone, y descubrirlo en la obra, con
-- el andamio ya puesto, es tarde.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'cae-documentos',
  'cae-documentos',
  false,
  20971520,
  array['application/pdf','image/jpeg','image/png','image/webp','image/heic']
)
on conflict (id) do nothing;

-- ─── De la ruta a la organización ────────────────────────────────────────────
-- Devuelve la organización dueña de una ruta de documento CAE, o NULL si la ruta
-- no es una ruta de documento CAE.
--
-- El patrón se comprueba con expresión regular ANTES de convertir a uuid a
-- propósito: `split_part(...)::uuid` sobre un texto que no es un uuid lanza
-- 22P02 y, dentro de una política, un error no es «no ves la fila» sino una
-- consulta rota. Comprobar primero convierte el fallo en un NULL, que es lo que
-- la política sabe tratar.
create or replace function public.fn_cae_org_de_ruta(p_ruta text)
returns uuid
language sql
immutable
set search_path to 'public'
as $$
  select case
    when p_ruta ~ '^cae-documentos/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/'
      then split_part(p_ruta, '/', 2)::uuid
    else null
  end
$$;

comment on function public.fn_cae_org_de_ruta(text) is
  'Organización dueña de un documento CAE, deducida de su ruta '
  '(cae-documentos/<organización>/<expediente>/<clave>/<fichero>). NULL si la ruta '
  'no sigue el patrón, para que la política de RLS niegue en vez de romperse.';

-- ─── `public.documents`: solo la rama CAE ────────────────────────────────────
create policy documents_cae_select on public.documents
  for select to authenticated
  using (public.fn_is_org_active_member(public.fn_cae_org_de_ruta(storage_path)));

-- `pact_id is null` está en el WITH CHECK para que nadie use esta puerta para
-- colgar un documento de un pacto ajeno: el vertical CAE existe precisamente
-- porque el expediente NO necesita pacto (spec §2).
create policy documents_cae_insert on public.documents
  for insert to authenticated
  with check (
    pact_id is null
    and public.fn_is_org_active_member(public.fn_cae_org_de_ruta(storage_path))
    and uploaded_by_user_id = public.current_user_id()
  );

-- Borrar un documento CAE se permite por UNA razón concreta: la compensación.
-- Supabase no da transacciones desde el cliente, así que la subida hace tres
-- escrituras (fichero, documento, requisito) y si una falla hay que deshacer las
-- anteriores. Sin DELETE, ese fallo dejaría una fila huérfana apuntando a un
-- fichero que nadie reclama. No alcanza a los documentos de pacto: la condición
-- de ruta lo impide.
create policy documents_cae_delete on public.documents
  for delete to authenticated
  using (public.fn_is_org_active_member(public.fn_cae_org_de_ruta(storage_path)));

-- Deliberadamente NO hay política de UPDATE. Un documento aportado es prueba: se
-- sustituye subiendo otro y reapuntando el requisito, no editando el hash.

-- ─── `storage.objects`: el mismo criterio, sobre el fichero ──────────────────
-- La fila de `documents` guarda la ruta con el cubo delante; el objeto de
-- Storage guarda `name` SIN el cubo. Se recompone para poder usar la misma
-- función y que no haya dos definiciones de «de quién es esto».
create policy cae_documentos_leer on storage.objects
  for select to authenticated
  using (
    bucket_id = 'cae-documentos'
    and public.fn_is_org_active_member(public.fn_cae_org_de_ruta('cae-documentos/' || name))
  );

create policy cae_documentos_subir on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'cae-documentos'
    and public.fn_is_org_active_member(public.fn_cae_org_de_ruta('cae-documentos/' || name))
  );

create policy cae_documentos_borrar on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'cae-documentos'
    and public.fn_is_org_active_member(public.fn_cae_org_de_ruta('cae-documentos/' || name))
  );
