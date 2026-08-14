-- La fecha en que la obra empezó DE VERDAD, declarada por el instalador.
--
-- Existe porque `estado` no puede acreditarlo y creíamos que sí. El disparador
-- `fn_cae_puerta_certificado_previo` impide SALIR de 'borrador' sin el
-- certificado energético previo; luego un expediente al que le falta ese papel
-- se queda clavado en 'borrador' AUNQUE la obra haya arrancado. Leer el estado
-- para decidir si la obra empezó es circular, y le decía «llegas a tiempo»
-- justo al único cliente que ya había llegado tarde.

alter table cae_expedientes
  add column obra_iniciada_at timestamptz;

comment on column cae_expedientes.obra_iniciada_at is
  'Fecha declarada de inicio de obra. Es INDEPENDIENTE de `estado`, a propósito: '
  'el estado depende de la puerta del certificado energético previo (un '
  'expediente sin ese papel no puede salir de «borrador» aunque la obra ya haya '
  'arrancado), así que el estado NO sirve para saber si la obra empezó. '
  'Sin esta columna no se puede afirmar que la obra no ha empezado: NULL '
  'significa «no consta», nunca «no ha empezado». Se rellena y se vacía desde la '
  'ficha del expediente sin pasar por la puerta del certificado — precisamente '
  'el caso que importa es declarar el inicio de una obra que sigue en borrador.';
