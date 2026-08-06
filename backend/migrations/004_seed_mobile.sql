-- Dados de demonstração para os wireframes Mobile.
-- Todas as contas abaixo usam a senha: Admin@123
BEGIN;

INSERT INTO usuario (id, nome, email, senha_hash, perfil, ativo) VALUES
  ('00000000-0000-0000-0000-000000000002', 'Escola de Desenvolvimento',
   'escola@ace.local', '$2a$10$cdsKFqwoj86GakZHa.3vKubpXRExvqlWg/WxijUtYgqmXBo.1YanK',
   'ESCOLA', TRUE),
  ('00000000-0000-0000-0000-000000000003', 'Atleta de Desenvolvimento',
   'atleta@ace.local', '$2a$10$cdsKFqwoj86GakZHa.3vKubpXRExvqlWg/WxijUtYgqmXBo.1YanK',
   'ALUNO', TRUE),
  ('00000000-0000-0000-0000-000000000004', 'Árbitro de Desenvolvimento',
   'arbitro@ace.local', '$2a$10$cdsKFqwoj86GakZHa.3vKubpXRExvqlWg/WxijUtYgqmXBo.1YanK',
   'ARBITRO', TRUE)
ON CONFLICT (email) DO NOTHING;

UPDATE escola
SET usuario_id = '00000000-0000-0000-0000-000000000002',
    telefone = '(13) 3421-0000',
    logradouro = 'Avenida das Escolas', numero = '100', bairro = 'Centro',
    cep = '11740000', atualizado_em = NOW()
WHERE id = '00000000-0000-0000-0000-000000000010';

INSERT INTO escola
  (id, nome, cnpj, cidade, estado, telefone, ativa)
VALUES
  ('00000000-0000-0000-0000-000000000011', 'Escola Visitante',
   '11111111111111', 'Itanhaém', 'SP', '(13) 3421-1111', TRUE)
ON CONFLICT (cnpj) DO NOTHING;

INSERT INTO aluno
  (id, usuario_id, escola_id, cpf, data_nascimento, matricula,
   genero, telefone, status_documentacao, ativo)
VALUES
  ('00000000-0000-0000-0000-000000000020',
   '00000000-0000-0000-0000-000000000003',
   '00000000-0000-0000-0000-000000000010',
   '12345678901', '2009-05-10', '20260001', 'MASCULINO',
   '(13) 99999-0001', 'APROVADA', TRUE)
ON CONFLICT (cpf) DO NOTHING;

INSERT INTO arbitro (id, usuario_id, registro, ativo)
VALUES
  ('00000000-0000-0000-0000-000000000030',
   '00000000-0000-0000-0000-000000000004', 'ARB-2026-001', TRUE)
ON CONFLICT (usuario_id) DO NOTHING;

INSERT INTO time_esportivo
  (id, escola_id, modalidade_id, categoria_id, nome, treinador, ativo)
SELECT
  '00000000-0000-0000-0000-000000000040',
  '00000000-0000-0000-0000-000000000010', m.id, c.id,
  'ACE Futsal', 'Técnico ACE', TRUE
FROM modalidade m, categoria c
WHERE m.nome = 'Futsal' AND c.nome = 'Sub-18 Masculino'
ON CONFLICT DO NOTHING;

INSERT INTO time_esportivo
  (id, escola_id, modalidade_id, categoria_id, nome, treinador, ativo)
SELECT
  '00000000-0000-0000-0000-000000000041',
  '00000000-0000-0000-0000-000000000011', m.id, c.id,
  'Visitante Futsal', 'Técnico Visitante', TRUE
FROM modalidade m, categoria c
WHERE m.nome = 'Futsal' AND c.nome = 'Sub-18 Masculino'
ON CONFLICT DO NOTHING;

INSERT INTO time_aluno
  (time_id, aluno_id, numero_camisa, posicao, funcao, capitao, titular, ativo)
VALUES
  ('00000000-0000-0000-0000-000000000040',
   '00000000-0000-0000-0000-000000000020', 10, 'Ala', 'JOGADOR', TRUE, TRUE, TRUE)
ON CONFLICT (time_id, aluno_id) DO UPDATE SET
  ativo = TRUE, capitao = TRUE, titular = TRUE;

INSERT INTO competicao
  (id, modalidade_id, categoria_id, organizador_id, nome, descricao,
   tipo, abrangencia, formato, status, data_inicio, data_fim, ativo)
SELECT
  '00000000-0000-0000-0000-000000000050', m.id, c.id,
  '00000000-0000-0000-0000-000000000001',
  'Jogos Escolares ACE 2026', 'Competição de demonstração mobile',
  'JOGOS_ESCOLARES', 'MUNICIPAL', 'PONTOS_CORRIDOS', 'EM_ANDAMENTO',
  CURRENT_DATE, CURRENT_DATE + 10, TRUE
FROM modalidade m, categoria c
WHERE m.nome = 'Futsal' AND c.nome = 'Sub-18 Masculino'
ON CONFLICT DO NOTHING;

INSERT INTO inscricao_competicao
  (competicao_id, time_id, status, inscrito_por)
VALUES
  ('00000000-0000-0000-0000-000000000050',
   '00000000-0000-0000-0000-000000000040', 'ATIVA',
   '00000000-0000-0000-0000-000000000002'),
  ('00000000-0000-0000-0000-000000000050',
   '00000000-0000-0000-0000-000000000041', 'ATIVA',
   '00000000-0000-0000-0000-000000000001')
ON CONFLICT (competicao_id, time_id) DO NOTHING;

INSERT INTO partida
  (id, competicao_id, time_casa_id, time_visitante_id, arbitro_id,
   data_hora, local, status, placar_casa, placar_visitante)
VALUES
  ('00000000-0000-0000-0000-000000000060',
   '00000000-0000-0000-0000-000000000050',
   '00000000-0000-0000-0000-000000000040',
   '00000000-0000-0000-0000-000000000041',
   '00000000-0000-0000-0000-000000000030',
   NOW(), 'Ginásio Municipal', 'EM_ANDAMENTO', 0, 0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO arbitragem_partida
  (partida_id, arbitro_id, funcao, ativo, designado_por)
VALUES
  ('00000000-0000-0000-0000-000000000060',
   '00000000-0000-0000-0000-000000000030', 'PRINCIPAL', TRUE,
   '00000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

COMMIT;
