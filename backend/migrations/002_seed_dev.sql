-- Dados mínimos para desenvolvimento. Não use estas credenciais em produção.
BEGIN;

INSERT INTO tipo_documento
  (nome, descricao, obrigatorio, extensoes_permitidas, tamanho_maximo_bytes)
VALUES
  ('Documento de identificação', 'RG, CIN ou documento equivalente.', TRUE,
   ARRAY['pdf', 'jpg', 'jpeg', 'png'], 8388608),
  ('Comprovante de matrícula', 'Comprovante atualizado da unidade escolar.', TRUE,
   ARRAY['pdf', 'jpg', 'jpeg', 'png'], 8388608),
  ('Atestado médico', 'Atestado de aptidão para prática esportiva.', TRUE,
   ARRAY['pdf', 'jpg', 'jpeg', 'png'], 8388608),
  ('Autorização do responsável', 'Autorização assinada para menores de idade.', TRUE,
   ARRAY['pdf', 'jpg', 'jpeg', 'png'], 8388608)
ON CONFLICT (nome) DO NOTHING;

INSERT INTO modalidade (nome, tipo_pontuacao) VALUES
  ('Futsal', 'GOLS'),
  ('Voleibol', 'SETS'),
  ('Basquetebol', 'PONTOS'),
  ('Handebol', 'GOLS')
ON CONFLICT (nome) DO NOTHING;

INSERT INTO categoria (nome, idade_minima, idade_maxima, genero) VALUES
  ('Sub-15 Masculino', 12, 15, 'MASCULINO'),
  ('Sub-15 Feminino', 12, 15, 'FEMININO'),
  ('Sub-18 Masculino', 15, 18, 'MASCULINO'),
  ('Sub-18 Feminino', 15, 18, 'FEMININO')
ON CONFLICT (nome) DO NOTHING;

INSERT INTO usuario (id, nome, email, senha_hash, perfil, ativo) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Administrador de Desenvolvimento',
   'admin@aether.local', '$2a$10$cdsKFqwoj86GakZHa.3vKubpXRExvqlWg/WxijUtYgqmXBo.1YanK',
   'ADMINISTRADOR', TRUE)
ON CONFLICT (email) DO NOTHING;

INSERT INTO escola (id, nome, cnpj, cidade, estado, ativa) VALUES
  ('00000000-0000-0000-0000-000000000010', 'Escola de Desenvolvimento',
   '00000000000000', 'Itanhaém', 'SP', TRUE)
ON CONFLICT (cnpj) DO NOTHING;

COMMIT;

-- Login de desenvolvimento:
-- e-mail: admin@aether.local
-- senha: Admin@123
-- escolaId para cadastrar alunos: 00000000-0000-0000-0000-000000000010
