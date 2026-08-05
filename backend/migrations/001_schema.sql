BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE perfil_usuario AS ENUM ('ADMINISTRADOR', 'ORGANIZADOR', 'ESCOLA', 'ALUNO', 'ARBITRO');
CREATE TYPE status_documentacao AS ENUM ('PENDENTE', 'EM_ANALISE', 'APROVADA', 'REJEITADA', 'CORRECAO_SOLICITADA');
CREATE TYPE status_competicao AS ENUM ('PLANEJADA', 'INSCRICOES_ABERTAS', 'EM_ANDAMENTO', 'ENCERRADA', 'CANCELADA');
CREATE TYPE status_inscricao AS ENUM ('ATIVA', 'CANCELADA', 'REJEITADA');
CREATE TYPE status_partida AS ENUM ('PLANEJADA', 'AGENDADA', 'EM_ANDAMENTO', 'ENCERRADA', 'CANCELADA');
CREATE TYPE tipo_evento_partida AS ENUM ('PONTUACAO', 'FALTA', 'CARTAO_AMARELO', 'CARTAO_VERMELHO', 'PENALIDADE', 'OBSERVACAO');

CREATE TABLE usuario (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome varchar(150) NOT NULL,
  email varchar(180) NOT NULL UNIQUE,
  senha_hash varchar(255) NOT NULL,
  perfil perfil_usuario NOT NULL,
  ativo boolean NOT NULL DEFAULT TRUE,
  ultimo_acesso timestamptz,
  criado_em timestamptz NOT NULL DEFAULT NOW(),
  atualizado_em timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE escola (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id uuid UNIQUE REFERENCES usuario(id),
  nome varchar(180) NOT NULL,
  cnpj varchar(14) UNIQUE,
  codigo_inep varchar(20) UNIQUE,
  telefone varchar(30),
  cidade varchar(100),
  estado char(2),
  ativa boolean NOT NULL DEFAULT TRUE,
  criado_em timestamptz NOT NULL DEFAULT NOW(),
  atualizado_em timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE aluno (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL UNIQUE REFERENCES usuario(id),
  escola_id uuid NOT NULL REFERENCES escola(id),
  cpf varchar(11) NOT NULL UNIQUE,
  data_nascimento date NOT NULL,
  matricula varchar(40),
  genero varchar(30),
  telefone varchar(30),
  status_documentacao status_documentacao NOT NULL DEFAULT 'PENDENTE',
  ativo boolean NOT NULL DEFAULT TRUE,
  criado_em timestamptz NOT NULL DEFAULT NOW(),
  atualizado_em timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE tipo_documento (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome varchar(100) NOT NULL UNIQUE,
  descricao text,
  obrigatorio boolean NOT NULL DEFAULT TRUE,
  extensoes_permitidas text[] NOT NULL DEFAULT ARRAY['pdf', 'jpg', 'jpeg', 'png'],
  tamanho_maximo_bytes bigint NOT NULL DEFAULT 8388608,
  ativo boolean NOT NULL DEFAULT TRUE,
  criado_em timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE documento_atleta (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  aluno_id uuid NOT NULL REFERENCES aluno(id),
  tipo_documento_id uuid REFERENCES tipo_documento(id),
  tipo varchar(100),
  nome_arquivo varchar(255) NOT NULL,
  mime_type varchar(120) NOT NULL,
  tamanho_bytes bigint NOT NULL CHECK (tamanho_bytes >= 0),
  arquivo_conteudo bytea,
  url_arquivo text,
  status status_documentacao NOT NULL DEFAULT 'PENDENTE',
  observacao text,
  enviado_por uuid NOT NULL REFERENCES usuario(id),
  validado_por uuid REFERENCES usuario(id),
  validado_em timestamptz,
  ativo boolean NOT NULL DEFAULT TRUE,
  removido_por uuid REFERENCES usuario(id),
  removido_em timestamptz,
  criado_em timestamptz NOT NULL DEFAULT NOW(),
  atualizado_em timestamptz NOT NULL DEFAULT NOW(),
  CHECK (arquivo_conteudo IS NOT NULL OR url_arquivo IS NOT NULL)
);

CREATE TABLE validacao_documento (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  documento_id uuid NOT NULL REFERENCES documento_atleta(id),
  status status_documentacao NOT NULL,
  justificativa text,
  validado_por uuid NOT NULL REFERENCES usuario(id),
  validado_em timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE modalidade (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome varchar(100) NOT NULL UNIQUE,
  tipo_pontuacao varchar(40) NOT NULL DEFAULT 'PONTOS',
  ativa boolean NOT NULL DEFAULT TRUE
);

CREATE TABLE categoria (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome varchar(80) NOT NULL UNIQUE,
  idade_minima smallint,
  idade_maxima smallint,
  genero varchar(30)
);

CREATE TABLE time_esportivo (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  escola_id uuid NOT NULL REFERENCES escola(id),
  modalidade_id uuid REFERENCES modalidade(id),
  categoria_id uuid REFERENCES categoria(id),
  nome varchar(150) NOT NULL,
  treinador varchar(150),
  ativo boolean NOT NULL DEFAULT TRUE,
  criado_em timestamptz NOT NULL DEFAULT NOW(),
  atualizado_em timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (escola_id, modalidade_id, categoria_id, nome)
);

CREATE TABLE time_aluno (
  time_id uuid NOT NULL REFERENCES time_esportivo(id),
  aluno_id uuid NOT NULL REFERENCES aluno(id),
  numero_camisa smallint,
  posicao varchar(60),
  capitao boolean NOT NULL DEFAULT FALSE,
  ativo boolean NOT NULL DEFAULT TRUE,
  vinculado_em timestamptz NOT NULL DEFAULT NOW(),
  PRIMARY KEY (time_id, aluno_id)
);

CREATE TABLE competicao (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  modalidade_id uuid REFERENCES modalidade(id),
  categoria_id uuid REFERENCES categoria(id),
  organizador_id uuid NOT NULL REFERENCES usuario(id),
  nome varchar(180) NOT NULL,
  descricao text,
  tipo varchar(60) NOT NULL DEFAULT 'COMPETICAO',
  abrangencia varchar(80),
  formato varchar(50) NOT NULL DEFAULT 'PONTOS_CORRIDOS',
  status status_competicao NOT NULL DEFAULT 'PLANEJADA',
  limite_times integer CHECK (limite_times IS NULL OR limite_times > 1),
  data_inicio date,
  data_fim date,
  data_limite_inscricao timestamptz,
  ativo boolean NOT NULL DEFAULT TRUE,
  justificativa_cancelamento text,
  excluida_em timestamptz,
  encerrada_em timestamptz,
  encerrada_por uuid REFERENCES usuario(id),
  criado_em timestamptz NOT NULL DEFAULT NOW(),
  atualizado_em timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE inscricao_competicao (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  competicao_id uuid NOT NULL REFERENCES competicao(id),
  time_id uuid NOT NULL REFERENCES time_esportivo(id),
  status status_inscricao NOT NULL DEFAULT 'ATIVA',
  inscrito_por uuid NOT NULL REFERENCES usuario(id),
  inscrito_em timestamptz NOT NULL DEFAULT NOW(),
  cancelado_por uuid REFERENCES usuario(id),
  cancelado_em timestamptz,
  UNIQUE (competicao_id, time_id)
);

CREATE TABLE edicao_jogos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  competicao_id uuid NOT NULL REFERENCES competicao(id),
  ano integer NOT NULL CHECK (ano BETWEEN 2000 AND 2200),
  nome varchar(180) NOT NULL,
  data_inicio date NOT NULL,
  data_fim date NOT NULL,
  status status_competicao NOT NULL DEFAULT 'PLANEJADA',
  configuracoes_copiadas jsonb NOT NULL DEFAULT '{}'::jsonb,
  criada_por uuid NOT NULL REFERENCES usuario(id),
  criado_em timestamptz NOT NULL DEFAULT NOW(),
  atualizado_em timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (competicao_id, ano),
  CHECK (data_fim >= data_inicio)
);

CREATE TABLE competicao_modalidade (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  competicao_id uuid NOT NULL REFERENCES competicao(id),
  modalidade_id uuid NOT NULL REFERENCES modalidade(id),
  jogadores_min integer CHECK (jogadores_min IS NULL OR jogadores_min > 0),
  jogadores_max integer CHECK (jogadores_max IS NULL OR jogadores_max > 0),
  limite_times integer CHECK (limite_times IS NULL OR limite_times > 1),
  regras jsonb NOT NULL DEFAULT '{}'::jsonb,
  ativa boolean NOT NULL DEFAULT TRUE,
  criado_em timestamptz NOT NULL DEFAULT NOW(),
  atualizado_em timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (competicao_id, modalidade_id)
);

CREATE TABLE competicao_categoria (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  competicao_id uuid NOT NULL REFERENCES competicao(id),
  categoria_id uuid NOT NULL REFERENCES categoria(id),
  data_referencia date,
  serie_min integer,
  serie_max integer,
  criterios jsonb NOT NULL DEFAULT '{}'::jsonb,
  ativa boolean NOT NULL DEFAULT TRUE,
  criado_em timestamptz NOT NULL DEFAULT NOW(),
  atualizado_em timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (competicao_id, categoria_id),
  CHECK (serie_min IS NULL OR serie_max IS NULL OR serie_max >= serie_min)
);

CREATE TABLE fase_competicao (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  competicao_id uuid NOT NULL REFERENCES competicao(id),
  nome varchar(120) NOT NULL,
  ordem integer NOT NULL CHECK (ordem > 0),
  tipo varchar(50) NOT NULL,
  quantidade_grupos integer CHECK (quantidade_grupos IS NULL OR quantidade_grupos > 0),
  classificados integer CHECK (classificados IS NULL OR classificados > 0),
  configuracao jsonb NOT NULL DEFAULT '{}'::jsonb,
  ativa boolean NOT NULL DEFAULT TRUE,
  criado_em timestamptz NOT NULL DEFAULT NOW(),
  atualizado_em timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (competicao_id, ordem)
);

CREATE TABLE grupo_competicao (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fase_id uuid NOT NULL REFERENCES fase_competicao(id),
  nome varchar(80) NOT NULL,
  ordem integer NOT NULL DEFAULT 1,
  criado_em timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (fase_id, nome)
);

CREATE TABLE regra_classificacao (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fase_id uuid NOT NULL REFERENCES fase_competicao(id),
  ordem integer NOT NULL DEFAULT 1,
  criterio varchar(80) NOT NULL,
  direcao varchar(10) NOT NULL DEFAULT 'DESC',
  configuracao jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (fase_id, ordem)
);

CREATE TABLE chaveamento (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  competicao_id uuid NOT NULL REFERENCES competicao(id),
  fase_id uuid REFERENCES fase_competicao(id),
  versao integer NOT NULL CHECK (versao > 0),
  metodo varchar(60) NOT NULL,
  semente bigint NOT NULL,
  status varchar(30) NOT NULL DEFAULT 'CONFIRMADO',
  criado_por uuid NOT NULL REFERENCES usuario(id),
  criado_em timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (competicao_id, versao)
);

CREATE TABLE chaveamento_item (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chaveamento_id uuid NOT NULL REFERENCES chaveamento(id),
  fase_id uuid REFERENCES fase_competicao(id),
  grupo_id uuid REFERENCES grupo_competicao(id),
  time_id uuid NOT NULL REFERENCES time_esportivo(id),
  posicao integer NOT NULL CHECK (posicao > 0),
  chave varchar(40),
  criado_em timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (chaveamento_id, time_id),
  UNIQUE (chaveamento_id, posicao)
);

CREATE TABLE local_partida (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome varchar(180) NOT NULL,
  tipo varchar(60) NOT NULL,
  capacidade integer CHECK (capacidade IS NULL OR capacidade >= 0),
  logradouro varchar(180),
  numero varchar(30),
  complemento varchar(100),
  bairro varchar(100),
  cidade varchar(100) NOT NULL,
  estado char(2) NOT NULL,
  cep varchar(8),
  instalacoes jsonb NOT NULL DEFAULT '{}'::jsonb,
  ativo boolean NOT NULL DEFAULT TRUE,
  criado_por uuid NOT NULL REFERENCES usuario(id),
  criado_em timestamptz NOT NULL DEFAULT NOW(),
  atualizado_em timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE local_modalidade (
  local_id uuid NOT NULL REFERENCES local_partida(id),
  modalidade_id uuid NOT NULL REFERENCES modalidade(id),
  PRIMARY KEY (local_id, modalidade_id)
);

CREATE TABLE arbitro (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL UNIQUE REFERENCES usuario(id),
  registro varchar(50),
  ativo boolean NOT NULL DEFAULT TRUE
);

CREATE TABLE partida (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  competicao_id uuid NOT NULL REFERENCES competicao(id),
  time_casa_id uuid NOT NULL REFERENCES time_esportivo(id),
  time_visitante_id uuid NOT NULL REFERENCES time_esportivo(id),
  arbitro_id uuid REFERENCES arbitro(id),
  fase_id uuid REFERENCES fase_competicao(id),
  chaveamento_item_id uuid REFERENCES chaveamento_item(id),
  local_partida_id uuid REFERENCES local_partida(id),
  rodada integer,
  data_hora timestamptz,
  local varchar(180),
  status status_partida NOT NULL DEFAULT 'PLANEJADA',
  placar_casa integer CHECK (placar_casa IS NULL OR placar_casa >= 0),
  placar_visitante integer CHECK (placar_visitante IS NULL OR placar_visitante >= 0),
  observacoes text,
  encerrada_em timestamptz,
  criado_em timestamptz NOT NULL DEFAULT NOW(),
  atualizado_em timestamptz NOT NULL DEFAULT NOW(),
  CHECK (time_casa_id <> time_visitante_id)
);

CREATE TABLE calendario_alteracao (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partida_id uuid NOT NULL REFERENCES partida(id),
  data_hora_anterior timestamptz,
  data_hora_nova timestamptz,
  local_anterior_id uuid REFERENCES local_partida(id),
  local_novo_id uuid REFERENCES local_partida(id),
  motivo text,
  alterado_por uuid NOT NULL REFERENCES usuario(id),
  alterado_em timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE resultado_publicado (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partida_id uuid NOT NULL UNIQUE REFERENCES partida(id),
  publicado_por uuid NOT NULL REFERENCES usuario(id),
  publicado_em timestamptz NOT NULL DEFAULT NOW(),
  revogado_em timestamptz
);

CREATE TABLE arbitragem_partida (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partida_id uuid NOT NULL REFERENCES partida(id),
  arbitro_id uuid NOT NULL REFERENCES arbitro(id),
  funcao varchar(50) NOT NULL DEFAULT 'PRINCIPAL',
  ativo boolean NOT NULL DEFAULT TRUE,
  designado_por uuid NOT NULL REFERENCES usuario(id),
  designado_em timestamptz NOT NULL DEFAULT NOW(),
  encerrado_em timestamptz
);

CREATE UNIQUE INDEX uq_arbitragem_funcao_ativa
  ON arbitragem_partida(partida_id, funcao)
  WHERE ativo = TRUE;

CREATE TABLE participacao_atleta (
  partida_id uuid NOT NULL REFERENCES partida(id),
  aluno_id uuid NOT NULL REFERENCES aluno(id),
  time_id uuid NOT NULL REFERENCES time_esportivo(id),
  titular boolean NOT NULL DEFAULT FALSE,
  pontos integer NOT NULL DEFAULT 0,
  assistencias integer NOT NULL DEFAULT 0,
  faltas integer NOT NULL DEFAULT 0,
  cartoes_amarelos integer NOT NULL DEFAULT 0,
  cartoes_vermelhos integer NOT NULL DEFAULT 0,
  nota numeric(4,2),
  atualizado_em timestamptz NOT NULL DEFAULT NOW(),
  PRIMARY KEY (partida_id, aluno_id)
);

CREATE TABLE evento_partida (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partida_id uuid NOT NULL REFERENCES partida(id),
  tipo tipo_evento_partida NOT NULL,
  time_id uuid REFERENCES time_esportivo(id),
  aluno_id uuid REFERENCES aluno(id),
  minuto integer CHECK (minuto IS NULL OR minuto >= 0),
  valor integer NOT NULL DEFAULT 1,
  observacao text,
  registrado_por uuid NOT NULL REFERENCES usuario(id),
  criado_em timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE sumula_partida (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partida_id uuid NOT NULL REFERENCES partida(id),
  versao integer NOT NULL CHECK (versao > 0),
  conteudo jsonb NOT NULL,
  emitida_por uuid NOT NULL REFERENCES usuario(id),
  emitida_em timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (partida_id, versao)
);

CREATE TABLE log_auditoria (
  id bigserial PRIMARY KEY,
  usuario_id uuid REFERENCES usuario(id),
  acao varchar(80) NOT NULL,
  entidade varchar(80) NOT NULL,
  entidade_id uuid,
  dados_anteriores jsonb,
  dados_novos jsonb,
  criado_em timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_aluno_escola ON aluno(escola_id) WHERE ativo = TRUE;
CREATE INDEX idx_partida_competicao_data ON partida(competicao_id, data_hora DESC);
CREATE INDEX idx_partida_times ON partida(time_casa_id, time_visitante_id);
CREATE INDEX idx_evento_partida ON evento_partida(partida_id, minuto);
CREATE INDEX idx_arbitragem_partida ON arbitragem_partida(partida_id) WHERE ativo = TRUE;
CREATE INDEX idx_sumula_partida ON sumula_partida(partida_id, versao DESC);
CREATE INDEX idx_participacao_aluno ON participacao_atleta(aluno_id, partida_id);
CREATE INDEX idx_inscricao_competicao ON inscricao_competicao(competicao_id, status);

CREATE INDEX idx_documento_aluno_status ON documento_atleta(aluno_id, status) WHERE ativo = TRUE;
CREATE INDEX idx_validacao_documento ON validacao_documento(documento_id, validado_em DESC);
CREATE INDEX idx_competicao_status_periodo ON competicao(status, data_inicio, data_fim) WHERE ativo = TRUE;
CREATE INDEX idx_fase_competicao ON fase_competicao(competicao_id, ordem) WHERE ativa = TRUE;
CREATE INDEX idx_chaveamento_competicao ON chaveamento(competicao_id, versao DESC);
CREATE INDEX idx_partida_calendario ON partida(data_hora, local_partida_id) WHERE status <> 'CANCELADA';
CREATE INDEX idx_calendario_alteracao ON calendario_alteracao(partida_id, alterado_em DESC);

CREATE OR REPLACE FUNCTION fn_classificacao_competicao(p_competicao_id uuid)
RETURNS TABLE (
  time_id uuid,
  time_nome varchar,
  jogos bigint,
  vitorias bigint,
  empates bigint,
  derrotas bigint,
  gols_pro bigint,
  gols_contra bigint,
  saldo_gols bigint,
  pontos bigint
)
LANGUAGE sql
STABLE
AS $$
  WITH jogos AS (
    SELECT p.time_casa_id AS time_id,
           p.placar_casa AS gp,
           p.placar_visitante AS gc
    FROM partida p
    WHERE p.competicao_id = p_competicao_id AND p.status = 'ENCERRADA'
    UNION ALL
    SELECT p.time_visitante_id,
           p.placar_visitante,
           p.placar_casa
    FROM partida p
    WHERE p.competicao_id = p_competicao_id AND p.status = 'ENCERRADA'
  )
  SELECT t.id,
         t.nome,
         COUNT(j.time_id) AS jogos,
         COUNT(*) FILTER (WHERE j.gp > j.gc) AS vitorias,
         COUNT(*) FILTER (WHERE j.gp = j.gc) AS empates,
         COUNT(*) FILTER (WHERE j.gp < j.gc) AS derrotas,
         COALESCE(SUM(j.gp), 0)::bigint AS gols_pro,
         COALESCE(SUM(j.gc), 0)::bigint AS gols_contra,
         COALESCE(SUM(j.gp - j.gc), 0)::bigint AS saldo_gols,
         (COUNT(*) FILTER (WHERE j.gp > j.gc) * 3 +
          COUNT(*) FILTER (WHERE j.gp = j.gc))::bigint AS pontos
  FROM inscricao_competicao i
  JOIN time_esportivo t ON t.id = i.time_id
  LEFT JOIN jogos j ON j.time_id = t.id
  WHERE i.competicao_id = p_competicao_id AND i.status = 'ATIVA'
  GROUP BY t.id, t.nome;
$$;

COMMIT;
