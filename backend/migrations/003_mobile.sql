-- Estruturas complementares para os casos de uso Mobile e Mobile + PC.
BEGIN;

ALTER TABLE escola
  ADD COLUMN IF NOT EXISTS logradouro varchar(180),
  ADD COLUMN IF NOT EXISTS numero varchar(30),
  ADD COLUMN IF NOT EXISTS complemento varchar(100),
  ADD COLUMN IF NOT EXISTS bairro varchar(100),
  ADD COLUMN IF NOT EXISTS cep varchar(8);

ALTER TABLE time_aluno
  ADD COLUMN IF NOT EXISTS funcao varchar(60),
  ADD COLUMN IF NOT EXISTS titular boolean NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS atualizado_em timestamptz NOT NULL DEFAULT NOW();

CREATE TABLE IF NOT EXISTS recuperacao_senha (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL REFERENCES usuario(id),
  codigo_hash varchar(64) NOT NULL,
  expira_em timestamptz NOT NULL,
  usado_em timestamptz,
  solicitado_em timestamptz NOT NULL DEFAULT NOW(),
  ip_solicitante inet
);

CREATE INDEX IF NOT EXISTS idx_recuperacao_senha_usuario
  ON recuperacao_senha(usuario_id, solicitado_em DESC);

CREATE INDEX IF NOT EXISTS idx_time_aluno_ativo
  ON time_aluno(time_id, ativo, titular);

CREATE INDEX IF NOT EXISTS idx_escola_nome_ativa
  ON escola(nome) WHERE ativa = TRUE;

COMMIT;
