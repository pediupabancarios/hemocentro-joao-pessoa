-- Segurança — etapa 1B. Rodar SÓ depois que o app com pront_login estiver publicado.
-- Converte as senhas restantes para hash, apaga o texto puro e fecha as colunas de senha.
-- Como as senhas ficaram expostas, quem ainda não trocou é obrigado a trocar no próximo login.

update public.usuarios set senha_hash = crypt(senha, gen_salt('bf'))
 where senha_hash is null and senha is not null;
update public.usuarios set trocar_senha = true, senha = null where senha is not null;

-- O app só lê nome e registro profissional direto da tabela; o resto passa pelas funções pront_*.
revoke all on public.usuarios from anon, authenticated;
grant select (id, nome, tipo, crm, conselho, ativo) on public.usuarios to anon, authenticated;
