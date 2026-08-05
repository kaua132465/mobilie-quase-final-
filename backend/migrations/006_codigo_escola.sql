BEGIN;

ALTER TABLE escola
  ADD COLUMN IF NOT EXISTS codigo_unidade char(3);

ALTER TABLE escola
  DROP CONSTRAINT IF EXISTS escola_codigo_unidade_formato;

ALTER TABLE escola
  ADD CONSTRAINT escola_codigo_unidade_formato
  CHECK (codigo_unidade IS NULL OR codigo_unidade ~ '^[0-9]{3}$');

CREATE UNIQUE INDEX IF NOT EXISTS escola_codigo_unidade_unique
  ON escola (codigo_unidade)
  WHERE codigo_unidade IS NOT NULL;

UPDATE escola SET codigo_unidade = '999'
WHERE id = '00000000-0000-0000-0000-000000000010'
  AND codigo_unidade IS NULL;

UPDATE escola SET codigo_unidade = '998'
WHERE id = '00000000-0000-0000-0000-000000000011'
  AND codigo_unidade IS NULL;

COMMIT;
