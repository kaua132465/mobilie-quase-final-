BEGIN;

ALTER TABLE aluno
  ADD COLUMN IF NOT EXISTS foto bytea,
  ADD COLUMN IF NOT EXISTS foto_mime_type varchar(30);

COMMIT;
