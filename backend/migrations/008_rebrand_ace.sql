BEGIN;

UPDATE usuario
SET email = replace(email, '@aether.local', '@ace.local'),
    atualizado_em = NOW()
WHERE email LIKE '%@aether.local';

UPDATE time_esportivo
SET nome = replace(nome, 'Aether', 'ACE'),
    treinador = replace(treinador, 'Aether', 'ACE'),
    atualizado_em = NOW()
WHERE nome LIKE '%Aether%' OR treinador LIKE '%Aether%';

UPDATE competicao
SET nome = replace(nome, 'Aether', 'ACE'),
    atualizado_em = NOW()
WHERE nome LIKE '%Aether%';

COMMIT;
