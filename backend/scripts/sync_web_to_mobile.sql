\set ON_ERROR_STOP on

\echo 'ACE_SYNC: iniciando sincronizacao WEB -> MOBILE'

BEGIN;
SET LOCAL client_min_messages = warning;

SELECT NOT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'postgres_fdw'
) AS remove_fdw_after_sync \gset

CREATE EXTENSION IF NOT EXISTS postgres_fdw;

CREATE SERVER ace_web_sync_server
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host :'web_host', port :'web_port', dbname :'web_database');

CREATE USER MAPPING FOR CURRENT_USER
    SERVER ace_web_sync_server
    OPTIONS (user :'web_user', password :'web_password');

CREATE SCHEMA ace_sync_source;

IMPORT FOREIGN SCHEMA public LIMIT TO (
    usuario,
    usuario_papel,
    papel,
    escola,
    vinculo_usuario_escola,
    esporte,
    modalidade,
    time,
    vinculo_time_escola,
    vinculo_tecnico_time,
    aluno,
    vinculo_time_integrante,
    funcao_integrante,
    escalacao_integrante,
    competicao,
    formato,
    inscricao_competicao,
    vinculo_inscricao_time,
    partida,
    info_partida,
    vinculo_partida_time
) FROM SERVER ace_web_sync_server INTO ace_sync_source;

CREATE TEMP TABLE sync_resultado (
    entidade text PRIMARY KEY,
    origem integer NOT NULL,
    existentes_antes integer NOT NULL,
    iguais_antes integer NOT NULL,
    ignorados integer NOT NULL DEFAULT 0
) ON COMMIT DROP;

-- IDs inteiros do Web nao cabem nas colunas UUID do Mobile. UUIDs novos sao
-- derivados de entidade + ID para serem estaveis em todas as execucoes.
CREATE TEMP TABLE map_usuario (
    source_id integer PRIMARY KEY,
    target_id uuid NOT NULL,
    existia boolean NOT NULL
) ON COMMIT DROP;

INSERT INTO map_usuario (source_id, target_id, existia)
SELECT s.cd_usuario,
       COALESCE(t.id, md5('ace-web:usuario:' || s.cd_usuario)::uuid),
       t.id IS NOT NULL
FROM ace_sync_source.usuario s
LEFT JOIN LATERAL (
    SELECT id FROM usuario
    WHERE lower(email) = lower(trim(s.email))
    ORDER BY id LIMIT 1
) t ON true;

INSERT INTO sync_resultado (entidade, origem, existentes_antes, iguais_antes)
SELECT 'usuario', count(*), count(*) FILTER (WHERE m.existia),
       count(*) FILTER (
           WHERE m.existia
             AND t.nome = s.nm_usuario
             AND lower(t.email) = lower(trim(s.email))
             AND t.senha_hash = s.senha
             AND t.ativo = s.ativo
       )
FROM ace_sync_source.usuario s
JOIN map_usuario m ON m.source_id = s.cd_usuario
LEFT JOIN usuario t ON t.id = m.target_id;

INSERT INTO usuario (
    id, nome, email, senha_hash, perfil, ativo, criado_em, atualizado_em
)
SELECT m.target_id,
       s.nm_usuario,
       lower(trim(s.email)),
       s.senha,
       CASE
           WHEN EXISTS (
               SELECT 1 FROM ace_sync_source.usuario_papel up
               JOIN ace_sync_source.papel p ON p.cd_papel = up.cd_papel
               WHERE up.cd_usuario = s.cd_usuario AND up.ativo AND p.nm_papel = 'ADM'
           ) THEN 'ADMINISTRADOR'
           WHEN EXISTS (
               SELECT 1 FROM ace_sync_source.usuario_papel up
               JOIN ace_sync_source.papel p ON p.cd_papel = up.cd_papel
               WHERE up.cd_usuario = s.cd_usuario AND up.ativo AND p.nm_papel = 'ARB'
           ) THEN 'ARBITRO'
           WHEN EXISTS (
               SELECT 1 FROM ace_sync_source.aluno a WHERE a.cd_usuario = s.cd_usuario
           ) THEN 'ALUNO'
           WHEN EXISTS (
               SELECT 1 FROM ace_sync_source.vinculo_usuario_escola vue
               JOIN ace_sync_source.papel p ON p.cd_papel = vue.cd_papel
               WHERE vue.cd_usuario = s.cd_usuario AND vue.ativo
                 AND p.nm_papel IN ('DIR', 'CRD', 'PRF')
           ) THEN 'ESCOLA'
           WHEN EXISTS (
               SELECT 1 FROM ace_sync_source.vinculo_usuario_escola vue
               JOIN ace_sync_source.papel p ON p.cd_papel = vue.cd_papel
               WHERE vue.cd_usuario = s.cd_usuario AND vue.ativo
                 AND p.nm_papel = 'ALU'
           ) THEN 'ALUNO'
           ELSE 'ORGANIZADOR'
       END::perfil_usuario,
       s.ativo,
       s.criado_em AT TIME ZONE 'America/Sao_Paulo',
       s.atualizado_em AT TIME ZONE 'America/Sao_Paulo'
FROM ace_sync_source.usuario s
JOIN map_usuario m ON m.source_id = s.cd_usuario
ON CONFLICT (email) DO UPDATE SET
    nome = EXCLUDED.nome,
    senha_hash = EXCLUDED.senha_hash,
    perfil = EXCLUDED.perfil,
    ativo = EXCLUDED.ativo,
    atualizado_em = EXCLUDED.atualizado_em
WHERE (usuario.nome, usuario.senha_hash, usuario.perfil, usuario.ativo)
      IS DISTINCT FROM
      (EXCLUDED.nome, EXCLUDED.senha_hash, EXCLUDED.perfil, EXCLUDED.ativo);

-- Atualiza o mapa caso o conflito por e-mail tenha preservado UUID preexistente.
UPDATE map_usuario m
SET target_id = t.id
FROM ace_sync_source.usuario s
JOIN usuario t ON lower(t.email) = lower(trim(s.email))
WHERE s.cd_usuario = m.source_id;

CREATE TEMP TABLE map_escola (
    source_id integer PRIMARY KEY,
    target_id uuid NOT NULL,
    existia boolean NOT NULL
) ON COMMIT DROP;

INSERT INTO map_escola (source_id, target_id, existia)
SELECT s.cd_escola,
       COALESCE(t.id, md5('ace-web:escola:' || s.cd_escola)::uuid),
       t.id IS NOT NULL
FROM ace_sync_source.escola s
LEFT JOIN LATERAL (
    SELECT id FROM escola
    WHERE lower(trim(nome)) = lower(trim(s.nm_escola))
    ORDER BY id LIMIT 1
) t ON true;

INSERT INTO sync_resultado (entidade, origem, existentes_antes, iguais_antes)
SELECT 'escola', count(*), count(*) FILTER (WHERE m.existia),
       count(*) FILTER (
           WHERE m.existia
             AND t.nome = s.nm_escola
             AND COALESCE(t.telefone, '') = COALESCE(s.telefone, '')
             AND COALESCE(t.cep, '') = COALESCE(regexp_replace(s.cep, '[^0-9]', '', 'g'), '')
             AND COALESCE(t.numero, '') = COALESCE(s.numero, '')
             AND t.ativa = s.ativa
       )
FROM ace_sync_source.escola s
JOIN map_escola m ON m.source_id = s.cd_escola
LEFT JOIN escola t ON t.id = m.target_id;

INSERT INTO escola (
    id, usuario_id, nome, telefone, cep, numero, ativa, criado_em, atualizado_em
)
SELECT me.target_id,
       diretor.target_id,
       s.nm_escola,
       s.telefone,
       nullif(regexp_replace(s.cep, '[^0-9]', '', 'g'), ''),
       s.numero,
       s.ativa,
       s.criada_em AT TIME ZONE 'America/Sao_Paulo',
       s.criada_em AT TIME ZONE 'America/Sao_Paulo'
FROM ace_sync_source.escola s
JOIN map_escola me ON me.source_id = s.cd_escola
LEFT JOIN LATERAL (
    SELECT mu.target_id
    FROM ace_sync_source.vinculo_usuario_escola vue
    JOIN ace_sync_source.papel p ON p.cd_papel = vue.cd_papel
    JOIN map_usuario mu ON mu.source_id = vue.cd_usuario
    WHERE vue.cd_escola = s.cd_escola AND vue.ativo AND p.nm_papel = 'DIR'
    ORDER BY vue.cd_usuario LIMIT 1
) diretor ON true
ON CONFLICT (id) DO UPDATE SET
    usuario_id = COALESCE(EXCLUDED.usuario_id, escola.usuario_id),
    nome = EXCLUDED.nome,
    telefone = EXCLUDED.telefone,
    cep = EXCLUDED.cep,
    numero = EXCLUDED.numero,
    ativa = EXCLUDED.ativa,
    atualizado_em = EXCLUDED.atualizado_em
WHERE (escola.usuario_id, escola.nome, escola.telefone, escola.cep,
       escola.numero, escola.ativa, escola.atualizado_em)
      IS DISTINCT FROM
      (COALESCE(EXCLUDED.usuario_id, escola.usuario_id), EXCLUDED.nome,
       EXCLUDED.telefone, EXCLUDED.cep, EXCLUDED.numero, EXCLUDED.ativa,
       EXCLUDED.atualizado_em);

CREATE TEMP TABLE map_modalidade (
    source_id integer PRIMARY KEY,
    target_id uuid NOT NULL,
    nome_target text NOT NULL,
    existia boolean NOT NULL
) ON COMMIT DROP;

INSERT INTO map_modalidade (source_id, target_id, nome_target, existia)
SELECT s.cd_esporte,
       COALESCE(t.id, md5('ace-web:esporte:' || s.cd_esporte)::uuid),
       n.nome_target,
       t.id IS NOT NULL
FROM ace_sync_source.esporte s
CROSS JOIN LATERAL (
    SELECT CASE s.nm_esporte
        WHEN 'Basquete' THEN 'Basquetebol'
        WHEN 'Vôlei' THEN 'Voleibol'
        ELSE s.nm_esporte
    END AS nome_target
) n
LEFT JOIN LATERAL (
    SELECT id FROM modalidade
    WHERE lower(nome) = lower(n.nome_target)
    ORDER BY id LIMIT 1
) t ON true;

INSERT INTO sync_resultado (entidade, origem, existentes_antes, iguais_antes)
SELECT 'modalidade', count(*), count(*) FILTER (WHERE m.existia),
       count(*) FILTER (
           WHERE m.existia AND t.nome = m.nome_target AND t.ativa
       )
FROM map_modalidade m
LEFT JOIN modalidade t ON t.id = m.target_id;

INSERT INTO modalidade (id, nome, tipo_pontuacao, ativa)
SELECT m.target_id,
       m.nome_target,
       CASE
           WHEN lower(m.nome_target) IN ('futsal', 'handebol') THEN 'GOLS'
           WHEN lower(m.nome_target) = 'voleibol' THEN 'SETS'
           ELSE 'PONTOS'
       END,
       true
FROM map_modalidade m
ON CONFLICT (id) DO UPDATE SET
    nome = EXCLUDED.nome,
    tipo_pontuacao = EXCLUDED.tipo_pontuacao,
    ativa = true
WHERE (modalidade.nome, modalidade.tipo_pontuacao, modalidade.ativa)
      IS DISTINCT FROM
      (EXCLUDED.nome, EXCLUDED.tipo_pontuacao, true);

CREATE TEMP TABLE map_categoria (
    source_id integer PRIMARY KEY,
    target_id uuid NOT NULL,
    nome_target text NOT NULL,
    genero_target text,
    idade_maxima smallint,
    existia boolean NOT NULL
) ON COMMIT DROP;

INSERT INTO map_categoria (
    source_id, target_id, nome_target, genero_target, idade_maxima, existia
)
SELECT s.cd_modalidade,
       COALESCE(t.id, md5('ace-web:modalidade:' || s.cd_modalidade)::uuid),
       n.nome_target,
       CASE s.sexo WHEN 'M' THEN 'MASCULINO' WHEN 'F' THEN 'FEMININO' ELSE 'MISTO' END,
       CASE s.categoria WHEN 'Sub14' THEN 14 WHEN 'Sub18' THEN 18 ELSE NULL END,
       t.id IS NOT NULL
FROM ace_sync_source.modalidade s
CROSS JOIN LATERAL (
    SELECT CASE
        WHEN s.categoria = 'Sub14' THEN 'Sub-14 '
        WHEN s.categoria = 'Sub18' THEN 'Sub-18 '
        ELSE 'Livre '
    END || CASE s.sexo
        WHEN 'M' THEN 'Masculino'
        WHEN 'F' THEN 'Feminino'
        ELSE 'Misto'
    END AS nome_target
) n
LEFT JOIN LATERAL (
    SELECT id FROM categoria
    WHERE lower(nome) = lower(n.nome_target)
    ORDER BY id LIMIT 1
) t ON true;

INSERT INTO sync_resultado (entidade, origem, existentes_antes, iguais_antes)
SELECT 'categoria', count(*), count(*) FILTER (WHERE m.existia),
       count(*) FILTER (
           WHERE m.existia
             AND t.nome = m.nome_target
             AND t.genero IS NOT DISTINCT FROM m.genero_target
             AND t.idade_maxima IS NOT DISTINCT FROM m.idade_maxima
       )
FROM map_categoria m
LEFT JOIN categoria t ON t.id = m.target_id;

INSERT INTO categoria (id, nome, idade_minima, idade_maxima, genero)
SELECT target_id,
       nome_target,
       CASE idade_maxima WHEN 14 THEN 10 WHEN 18 THEN 15 ELSE NULL END,
       idade_maxima,
       genero_target
FROM map_categoria
ON CONFLICT (id) DO UPDATE SET
    nome = EXCLUDED.nome,
    idade_minima = EXCLUDED.idade_minima,
    idade_maxima = EXCLUDED.idade_maxima,
    genero = EXCLUDED.genero
WHERE (categoria.nome, categoria.idade_minima, categoria.idade_maxima, categoria.genero)
      IS DISTINCT FROM
      (EXCLUDED.nome, EXCLUDED.idade_minima, EXCLUDED.idade_maxima, EXCLUDED.genero);

CREATE TEMP TABLE map_aluno (
    source_id integer PRIMARY KEY,
    target_id uuid NOT NULL,
    existia boolean NOT NULL
) ON COMMIT DROP;

INSERT INTO map_aluno (source_id, target_id, existia)
SELECT s.cd_aluno,
       COALESCE(t.id, md5('ace-web:aluno:' || s.cd_aluno)::uuid),
       t.id IS NOT NULL
FROM ace_sync_source.aluno s
JOIN map_usuario mu ON mu.source_id = s.cd_usuario
LEFT JOIN aluno t ON t.usuario_id = mu.target_id;

INSERT INTO sync_resultado (entidade, origem, existentes_antes, iguais_antes, ignorados)
SELECT 'aluno',
       (SELECT count(*) FROM ace_sync_source.aluno),
       count(*) FILTER (WHERE ma.existia),
       count(*) FILTER (
           WHERE ma.existia
             AND t.data_nascimento = s.data_nascimento
             AND COALESCE(t.matricula, '') = COALESCE(s.ra, '')
             AND t.ativo = s.ativo
       ),
       (SELECT count(*) FROM ace_sync_source.aluno) - count(*)
FROM map_aluno ma
JOIN ace_sync_source.aluno s ON s.cd_aluno = ma.source_id
LEFT JOIN aluno t ON t.id = ma.target_id;

INSERT INTO aluno (
    id, usuario_id, escola_id, cpf, data_nascimento, matricula,
    genero, telefone, status_documentacao, ativo, criado_em, atualizado_em
)
SELECT ma.target_id,
       mu.target_id,
       me.target_id,
       COALESCE(existente.cpf, lpad(regexp_replace(s.ra, '[^0-9]', '', 'g'), 11, '0')),
       s.data_nascimento,
       s.ra,
       CASE s.sexo WHEN 'M' THEN 'MASCULINO' WHEN 'F' THEN 'FEMININO' ELSE s.sexo END,
       s.telefone,
       'PENDENTE'::status_documentacao,
       s.ativo,
       s.criado_em AT TIME ZONE 'America/Sao_Paulo',
       s.atualizado_em AT TIME ZONE 'America/Sao_Paulo'
FROM ace_sync_source.aluno s
JOIN map_aluno ma ON ma.source_id = s.cd_aluno
JOIN map_usuario mu ON mu.source_id = s.cd_usuario
JOIN LATERAL (
    SELECT mes.target_id
    FROM ace_sync_source.vinculo_usuario_escola vue
    JOIN ace_sync_source.papel p ON p.cd_papel = vue.cd_papel
    JOIN map_escola mes ON mes.source_id = vue.cd_escola
    WHERE vue.cd_usuario = s.cd_usuario AND vue.ativo AND p.nm_papel = 'ALU'
    ORDER BY vue.cd_escola LIMIT 1
) me ON true
LEFT JOIN aluno existente ON existente.usuario_id = mu.target_id
WHERE s.data_nascimento IS NOT NULL
ON CONFLICT (usuario_id) DO UPDATE SET
    escola_id = EXCLUDED.escola_id,
    data_nascimento = EXCLUDED.data_nascimento,
    matricula = EXCLUDED.matricula,
    genero = EXCLUDED.genero,
    telefone = EXCLUDED.telefone,
    ativo = EXCLUDED.ativo,
    atualizado_em = EXCLUDED.atualizado_em
WHERE (aluno.escola_id, aluno.data_nascimento, aluno.matricula,
       aluno.genero, aluno.telefone, aluno.ativo, aluno.atualizado_em)
      IS DISTINCT FROM
      (EXCLUDED.escola_id, EXCLUDED.data_nascimento, EXCLUDED.matricula,
       EXCLUDED.genero, EXCLUDED.telefone, EXCLUDED.ativo, EXCLUDED.atualizado_em);

UPDATE map_aluno ma
SET target_id = a.id
FROM ace_sync_source.aluno s
JOIN map_usuario mu ON mu.source_id = s.cd_usuario
JOIN aluno a ON a.usuario_id = mu.target_id
WHERE s.cd_aluno = ma.source_id;

CREATE TEMP TABLE map_time (
    source_id integer PRIMARY KEY,
    target_id uuid NOT NULL,
    existia boolean NOT NULL
) ON COMMIT DROP;

INSERT INTO map_time (source_id, target_id, existia)
SELECT s.cd_time,
       COALESCE(t.id, md5('ace-web:time:' || s.cd_time)::uuid),
       t.id IS NOT NULL
FROM ace_sync_source.time s
JOIN LATERAL (
    SELECT me.target_id AS escola_id
    FROM ace_sync_source.vinculo_time_escola vte
    JOIN map_escola me ON me.source_id = vte.cd_escola
    WHERE vte.cd_time = s.cd_time AND vte.ativo
    ORDER BY vte.cd_escola LIMIT 1
) escola_map ON true
JOIN map_modalidade mm ON mm.source_id = s.cd_esporte
LEFT JOIN LATERAL (
    SELECT id FROM time_esportivo
    WHERE escola_id = escola_map.escola_id
      AND modalidade_id = mm.target_id
      AND lower(nome) = lower(s.nm_time)
    ORDER BY id LIMIT 1
) t ON true;

INSERT INTO sync_resultado (entidade, origem, existentes_antes, iguais_antes, ignorados)
SELECT 'time_esportivo',
       (SELECT count(*) FROM ace_sync_source.time),
       count(*) FILTER (WHERE mt.existia),
       count(*) FILTER (
           WHERE mt.existia AND t.nome = s.nm_time AND t.ativo = s.ativo
       ),
       (SELECT count(*) FROM ace_sync_source.time) - count(*)
FROM map_time mt
JOIN ace_sync_source.time s ON s.cd_time = mt.source_id
LEFT JOIN time_esportivo t ON t.id = mt.target_id;

INSERT INTO time_esportivo (
    id, escola_id, modalidade_id, categoria_id, nome, treinador,
    ativo, criado_em, atualizado_em
)
SELECT mt.target_id,
       escola_map.escola_id,
       mm.target_id,
       NULL,
       s.nm_time,
       tecnico.nm_usuario,
       s.ativo,
       s.criado_em AT TIME ZONE 'America/Sao_Paulo',
       s.atualizado_em AT TIME ZONE 'America/Sao_Paulo'
FROM ace_sync_source.time s
JOIN map_time mt ON mt.source_id = s.cd_time
JOIN LATERAL (
    SELECT me.target_id AS escola_id
    FROM ace_sync_source.vinculo_time_escola vte
    JOIN map_escola me ON me.source_id = vte.cd_escola
    WHERE vte.cd_time = s.cd_time AND vte.ativo
    ORDER BY vte.cd_escola LIMIT 1
) escola_map ON true
JOIN map_modalidade mm ON mm.source_id = s.cd_esporte
LEFT JOIN LATERAL (
    SELECT u.nm_usuario
    FROM ace_sync_source.vinculo_tecnico_time vtt
    JOIN ace_sync_source.usuario u ON u.cd_usuario = vtt.cd_usuario
    WHERE vtt.cd_time = s.cd_time AND vtt.ativo
    ORDER BY vtt.cd_usuario LIMIT 1
) tecnico ON true
ON CONFLICT (id) DO UPDATE SET
    escola_id = EXCLUDED.escola_id,
    modalidade_id = EXCLUDED.modalidade_id,
    nome = EXCLUDED.nome,
    treinador = EXCLUDED.treinador,
    ativo = EXCLUDED.ativo,
    atualizado_em = EXCLUDED.atualizado_em
WHERE (time_esportivo.escola_id, time_esportivo.modalidade_id,
       time_esportivo.nome, time_esportivo.treinador,
       time_esportivo.ativo, time_esportivo.atualizado_em)
      IS DISTINCT FROM
      (EXCLUDED.escola_id, EXCLUDED.modalidade_id, EXCLUDED.nome,
       EXCLUDED.treinador, EXCLUDED.ativo, EXCLUDED.atualizado_em);

INSERT INTO sync_resultado (entidade, origem, existentes_antes, iguais_antes, ignorados)
SELECT 'time_aluno',
       count(*),
       count(*) FILTER (WHERE ta.time_id IS NOT NULL),
       count(*) FILTER (
           WHERE ta.time_id IS NOT NULL
             AND ta.numero_camisa IS NOT DISTINCT FROM vti.numero_camisa::smallint
             AND ta.capitao = vti.capitao
             AND ta.ativo = vti.ativo
       ),
       count(*) FILTER (WHERE ma.source_id IS NULL OR mt.source_id IS NULL)
FROM ace_sync_source.vinculo_time_integrante vti
LEFT JOIN ace_sync_source.aluno sa ON sa.cd_usuario = vti.cd_usuario
LEFT JOIN map_aluno ma ON ma.source_id = sa.cd_aluno
LEFT JOIN map_time mt ON mt.source_id = vti.cd_time
LEFT JOIN time_aluno ta ON ta.time_id = mt.target_id AND ta.aluno_id = ma.target_id
WHERE vti.ativo;

INSERT INTO time_aluno (
    time_id, aluno_id, numero_camisa, posicao, capitao,
    ativo, vinculado_em, funcao, titular, atualizado_em
)
SELECT mt.target_id,
       ma.target_id,
       vti.numero_camisa::smallint,
       fi.nm_funcao,
       vti.capitao,
       vti.ativo,
       now(),
       fi.nm_funcao,
       COALESCE(ei.titular, false),
       now()
FROM ace_sync_source.vinculo_time_integrante vti
JOIN ace_sync_source.aluno sa ON sa.cd_usuario = vti.cd_usuario
JOIN map_aluno ma ON ma.source_id = sa.cd_aluno
JOIN map_time mt ON mt.source_id = vti.cd_time
LEFT JOIN ace_sync_source.funcao_integrante fi
       ON fi.cd_funcao_integrante = vti.cd_funcao_integrante
LEFT JOIN ace_sync_source.escalacao_integrante ei
       ON ei.cd_vinculo_time_integrante = vti.cd_vinculo_time_integrante
      AND ei.ativo
WHERE vti.ativo
ON CONFLICT (time_id, aluno_id) DO UPDATE SET
    numero_camisa = EXCLUDED.numero_camisa,
    posicao = EXCLUDED.posicao,
    capitao = EXCLUDED.capitao,
    ativo = EXCLUDED.ativo,
    funcao = EXCLUDED.funcao,
    titular = EXCLUDED.titular,
    atualizado_em = now()
WHERE (time_aluno.numero_camisa, time_aluno.posicao, time_aluno.capitao,
       time_aluno.ativo, time_aluno.funcao, time_aluno.titular)
      IS DISTINCT FROM
      (EXCLUDED.numero_camisa, EXCLUDED.posicao, EXCLUDED.capitao,
       EXCLUDED.ativo, EXCLUDED.funcao, EXCLUDED.titular);

CREATE TEMP TABLE map_competicao (
    source_id integer PRIMARY KEY,
    target_id uuid NOT NULL,
    existia boolean NOT NULL
) ON COMMIT DROP;

INSERT INTO map_competicao (source_id, target_id, existia)
SELECT s.cd_competicao,
       COALESCE(t.id, md5('ace-web:competicao:' || s.cd_competicao)::uuid),
       t.id IS NOT NULL
FROM ace_sync_source.competicao s
LEFT JOIN LATERAL (
    SELECT id FROM competicao
    WHERE lower(nome) = lower(s.nm_competicao)
    ORDER BY id LIMIT 1
) t ON true;

INSERT INTO sync_resultado (entidade, origem, existentes_antes, iguais_antes)
SELECT 'competicao', count(*), count(*) FILTER (WHERE mc.existia),
       count(*) FILTER (
           WHERE mc.existia
             AND t.nome = s.nm_competicao
             AND COALESCE(t.descricao, '') = COALESCE(s.descricao, '')
       )
FROM map_competicao mc
JOIN ace_sync_source.competicao s ON s.cd_competicao = mc.source_id
LEFT JOIN competicao t ON t.id = mc.target_id;

INSERT INTO competicao (
    id, modalidade_id, categoria_id, organizador_id, nome, descricao,
    formato, status, data_inicio, data_fim, ativo, criado_em, atualizado_em
)
SELECT mc.target_id,
       mm.target_id,
       mcat.target_id,
       COALESCE(mu.target_id, admin_mobile.id),
       s.nm_competicao,
       s.descricao,
       f.nm_formato,
       CASE s.status
           WHEN 'INSCRICOES_ABERTAS' THEN 'INSCRICOES_ABERTAS'
           WHEN 'EM_ANDAMENTO' THEN 'EM_ANDAMENTO'
           WHEN 'ENCERRADA' THEN 'ENCERRADA'
           WHEN 'CANCELADA' THEN 'CANCELADA'
           ELSE 'PLANEJADA'
       END::status_competicao,
       s.inicio_em::date,
       s.fim_em::date,
       true,
       s.criado_em AT TIME ZONE 'America/Sao_Paulo',
       s.criado_em AT TIME ZONE 'America/Sao_Paulo'
FROM ace_sync_source.competicao s
JOIN map_competicao mc ON mc.source_id = s.cd_competicao
JOIN map_modalidade mm ON mm.source_id = s.cd_esporte
JOIN map_categoria mcat ON mcat.source_id = s.cd_modalidade
JOIN ace_sync_source.formato f ON f.cd_formato = s.cd_formato
LEFT JOIN map_usuario mu ON mu.source_id = s.cd_criador
JOIN LATERAL (
    SELECT id FROM usuario WHERE perfil = 'ADMINISTRADOR' ORDER BY criado_em, id LIMIT 1
) admin_mobile ON true
ON CONFLICT (id) DO UPDATE SET
    modalidade_id = EXCLUDED.modalidade_id,
    categoria_id = EXCLUDED.categoria_id,
    organizador_id = EXCLUDED.organizador_id,
    nome = EXCLUDED.nome,
    descricao = EXCLUDED.descricao,
    formato = EXCLUDED.formato,
    status = EXCLUDED.status,
    data_inicio = EXCLUDED.data_inicio,
    data_fim = EXCLUDED.data_fim,
    ativo = EXCLUDED.ativo,
    atualizado_em = EXCLUDED.atualizado_em
WHERE (competicao.modalidade_id, competicao.categoria_id,
       competicao.organizador_id, competicao.nome, competicao.descricao,
       competicao.formato, competicao.status, competicao.data_inicio,
       competicao.data_fim, competicao.ativo)
      IS DISTINCT FROM
      (EXCLUDED.modalidade_id, EXCLUDED.categoria_id,
       EXCLUDED.organizador_id, EXCLUDED.nome, EXCLUDED.descricao,
       EXCLUDED.formato, EXCLUDED.status, EXCLUDED.data_inicio,
       EXCLUDED.data_fim, EXCLUDED.ativo);

INSERT INTO inscricao_competicao (
    id, competicao_id, time_id, status, inscrito_por, inscrito_em
)
SELECT md5('ace-web:inscricao:' || vit.cd_inscricao_competicao || ':' || vit.cd_time)::uuid,
       mc.target_id,
       mt.target_id,
       CASE WHEN vit.ativo THEN 'ATIVA' ELSE 'CANCELADA' END::status_inscricao,
       c.organizador_id,
       vit.inscrito_em AT TIME ZONE 'America/Sao_Paulo'
FROM ace_sync_source.vinculo_inscricao_time vit
JOIN ace_sync_source.inscricao_competicao si
     ON si.cd_inscricao_competicao = vit.cd_inscricao_competicao
JOIN map_competicao mc ON mc.source_id = si.cd_competicao
JOIN map_time mt ON mt.source_id = vit.cd_time
JOIN competicao c ON c.id = mc.target_id
ON CONFLICT (competicao_id, time_id) DO UPDATE SET
    status = EXCLUDED.status,
    inscrito_por = EXCLUDED.inscrito_por,
    inscrito_em = EXCLUDED.inscrito_em
WHERE (inscricao_competicao.status, inscricao_competicao.inscrito_por,
       inscricao_competicao.inscrito_em)
      IS DISTINCT FROM
      (EXCLUDED.status, EXCLUDED.inscrito_por, EXCLUDED.inscrito_em);

INSERT INTO sync_resultado (entidade, origem, existentes_antes, iguais_antes, ignorados)
SELECT 'inscricao_competicao', count(*),
       count(*) FILTER (WHERE alvo.id IS NOT NULL),
       count(*) FILTER (
           WHERE alvo.id IS NOT NULL
             AND alvo.status = CASE WHEN vit.ativo THEN 'ATIVA' ELSE 'CANCELADA' END::status_inscricao
       ),
       count(*) FILTER (WHERE mc.source_id IS NULL OR mt.source_id IS NULL)
FROM ace_sync_source.vinculo_inscricao_time vit
JOIN ace_sync_source.inscricao_competicao si
     ON si.cd_inscricao_competicao = vit.cd_inscricao_competicao
LEFT JOIN map_competicao mc ON mc.source_id = si.cd_competicao
LEFT JOIN map_time mt ON mt.source_id = vit.cd_time
LEFT JOIN inscricao_competicao alvo
       ON alvo.competicao_id = mc.target_id AND alvo.time_id = mt.target_id;

CREATE TEMP TABLE map_partida (
    source_id integer PRIMARY KEY,
    target_id uuid NOT NULL,
    existia boolean NOT NULL
) ON COMMIT DROP;

INSERT INTO map_partida (source_id, target_id, existia)
SELECT s.cd_partida,
       COALESCE(t.id, md5('ace-web:partida:' || s.cd_partida)::uuid),
       t.id IS NOT NULL
FROM ace_sync_source.partida s
LEFT JOIN partida t ON t.id = md5('ace-web:partida:' || s.cd_partida)::uuid;

INSERT INTO sync_resultado (entidade, origem, existentes_antes, iguais_antes, ignorados)
SELECT 'partida',
       (SELECT count(*) FROM ace_sync_source.partida),
       count(*) FILTER (WHERE mp.existia),
       count(*) FILTER (WHERE mp.existia AND alvo.status::text = src.status),
       (SELECT count(*) FROM ace_sync_source.partida) - count(*)
FROM map_partida mp
JOIN ace_sync_source.partida src ON src.cd_partida = mp.source_id
JOIN map_competicao mc ON mc.source_id = src.cd_competicao
JOIN ace_sync_source.vinculo_partida_time casa
     ON casa.cd_partida = src.cd_partida AND casa.mandante
JOIN ace_sync_source.vinculo_partida_time visita
     ON visita.cd_partida = src.cd_partida AND NOT visita.mandante
JOIN map_time mtc ON mtc.source_id = casa.cd_time
JOIN map_time mtv ON mtv.source_id = visita.cd_time
LEFT JOIN partida alvo ON alvo.id = mp.target_id;

INSERT INTO partida (
    id, competicao_id, time_casa_id, time_visitante_id, data_hora,
    local, status, observacoes, criado_em, atualizado_em
)
SELECT mp.target_id,
       mc.target_id,
       mtc.target_id,
       mtv.target_id,
       COALESCE(ip.inicio_em AT TIME ZONE 'America/Sao_Paulo',
                src.inicio_agendado AT TIME ZONE 'America/Sao_Paulo'),
       ip.local_partida,
       CASE src.status
           WHEN 'AGENDADA' THEN 'AGENDADA'
           WHEN 'EM_ANDAMENTO' THEN 'EM_ANDAMENTO'
           WHEN 'ENCERRADA' THEN 'ENCERRADA'
           WHEN 'CANCELADA' THEN 'CANCELADA'
           ELSE 'PLANEJADA'
       END::status_partida,
       ip.observacoes,
       now(),
       now()
FROM ace_sync_source.partida src
JOIN map_partida mp ON mp.source_id = src.cd_partida
JOIN map_competicao mc ON mc.source_id = src.cd_competicao
JOIN ace_sync_source.vinculo_partida_time casa
     ON casa.cd_partida = src.cd_partida AND casa.mandante
JOIN ace_sync_source.vinculo_partida_time visita
     ON visita.cd_partida = src.cd_partida AND NOT visita.mandante
JOIN map_time mtc ON mtc.source_id = casa.cd_time
JOIN map_time mtv ON mtv.source_id = visita.cd_time
LEFT JOIN ace_sync_source.info_partida ip ON ip.cd_partida = src.cd_partida
ON CONFLICT (id) DO UPDATE SET
    competicao_id = EXCLUDED.competicao_id,
    time_casa_id = EXCLUDED.time_casa_id,
    time_visitante_id = EXCLUDED.time_visitante_id,
    data_hora = EXCLUDED.data_hora,
    local = EXCLUDED.local,
    status = EXCLUDED.status,
    observacoes = EXCLUDED.observacoes,
    atualizado_em = now()
WHERE (partida.competicao_id, partida.time_casa_id,
       partida.time_visitante_id, partida.data_hora, partida.local,
       partida.status, partida.observacoes)
      IS DISTINCT FROM
      (EXCLUDED.competicao_id, EXCLUDED.time_casa_id,
       EXCLUDED.time_visitante_id, EXCLUDED.data_hora, EXCLUDED.local,
       EXCLUDED.status, EXCLUDED.observacoes);

\echo 'ACE_SYNC: resumo calculado antes da gravacao'
SELECT entidade,
       origem,
       existentes_antes,
       origem - existentes_antes - ignorados AS adicionados,
       existentes_antes - iguais_antes AS atualizados,
       iguais_antes AS ja_iguais,
       ignorados
FROM sync_resultado
ORDER BY entidade;

\echo 'ACE_SYNC: validacao de foreign keys'
SET CONSTRAINTS ALL IMMEDIATE;

DROP SERVER ace_web_sync_server CASCADE;
DROP SCHEMA ace_sync_source;

\if :remove_fdw_after_sync
DROP EXTENSION postgres_fdw;
\endif

\if :dry_run
\echo 'ACE_SYNC: dry-run concluido; executando ROLLBACK'
ROLLBACK;
\else
\echo 'ACE_SYNC: sincronizacao validada; executando COMMIT'
COMMIT;
\endif
