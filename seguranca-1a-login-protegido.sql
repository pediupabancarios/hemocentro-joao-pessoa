-- Segurança — etapa 1A (só acrescenta; o app antigo continua funcionando).
-- O login passa a ser conferido no banco (função pront_login), com senha em hash bcrypt
-- e sessão por token. A tabela usuarios ainda fica aberta até a etapa 1B.

alter table public.usuarios alter column senha drop not null;
alter table public.usuarios add column if not exists senha_hash text;
alter table public.usuarios add column if not exists trocar_senha boolean not null default false;

create table if not exists public.pront_sessoes (
  token_hash text primary key,
  usuario_id uuid not null references public.usuarios(id) on delete cascade,
  criado_em  timestamptz not null default now(),
  expira_em  timestamptz not null
);
alter table public.pront_sessoes enable row level security;
revoke all on public.pront_sessoes from anon, authenticated, public;

-- Usuário dono de um token válido (uso interno).
create or replace function public.pront_usuario_sessao(p_token text) returns public.usuarios
language sql stable security definer set search_path = public, extensions as $$
  select u.* from public.pront_sessoes s join public.usuarios u on u.id = s.usuario_id
  where s.token_hash = encode(digest(coalesce(p_token,''), 'sha256'), 'hex') and s.expira_em > now() and u.ativo
$$;

create or replace function public.pront_senha_confere(u public.usuarios, p_senha text) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select case when u.senha_hash is not null then u.senha_hash = crypt(coalesce(p_senha,''), u.senha_hash)
              else u.senha is not null and u.senha = p_senha end
$$;

create or replace function public.pront_publico(u public.usuarios) returns jsonb
language sql immutable as $$
  select jsonb_build_object('id', u.id, 'nome', u.nome, 'login', u.login, 'tipo', u.tipo, 'crm', u.crm,
                            'conselho', u.conselho, 'ativo', u.ativo, 'created_at', u.created_at, 'trocar_senha', u.trocar_senha)
$$;

create or replace function public.pront_login(p_login text, p_senha text, p_tipo text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare u public.usuarios; v_token text;
begin
  select * into u from public.usuarios where lower(login) = lower(trim(p_login)) and ativo limit 1;
  if u.id is null or not public.pront_senha_confere(u, p_senha) then
    perform pg_sleep(0.8); -- atrasa quem tenta adivinhar senhas
    return jsonb_build_object('ok', false, 'motivo', 'credenciais');
  end if;
  if u.tipo is distinct from p_tipo then
    return jsonb_build_object('ok', false, 'motivo', 'perfil');
  end if;
  if u.senha_hash is null then
    update public.usuarios set senha_hash = crypt(p_senha, gen_salt('bf')) where id = u.id;
  end if;
  delete from public.pront_sessoes where expira_em < now();
  v_token := encode(gen_random_bytes(32), 'hex');
  insert into public.pront_sessoes (token_hash, usuario_id, expira_em)
  values (encode(digest(v_token, 'sha256'), 'hex'), u.id, now() + interval '14 hours');
  return jsonb_build_object('ok', true, 'token', v_token, 'usuario', public.pront_publico(u), 'trocar_senha', u.trocar_senha);
end $$;

create or replace function public.pront_logout(p_token text) returns void
language sql security definer set search_path = public, extensions as $$
  delete from public.pront_sessoes where token_hash = encode(digest(coalesce(p_token,''), 'sha256'), 'hex')
$$;

create or replace function public.pront_trocar_senha(p_token text, p_atual text, p_nova text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare u public.usuarios := public.pront_usuario_sessao(p_token);
begin
  if u.id is null then raise exception 'Sessão expirada. Entre novamente.'; end if;
  if not public.pront_senha_confere(u, p_atual) then perform pg_sleep(0.8); raise exception 'Senha atual incorreta'; end if;
  if length(coalesce(p_nova,'')) < 8 then raise exception 'A nova senha precisa ter pelo menos 8 caracteres'; end if;
  if p_nova = p_atual then raise exception 'A nova senha precisa ser diferente da atual'; end if;
  update public.usuarios set senha_hash = crypt(p_nova, gen_salt('bf')), senha = null, trocar_senha = false where id = u.id;
end $$;

create or replace function public.pront_listar_usuarios(p_token text) returns setof jsonb
language plpgsql stable security definer set search_path = public, extensions as $$
declare g public.usuarios := public.pront_usuario_sessao(p_token);
begin
  if g.id is null or g.tipo <> 'gestor' then raise exception 'Apenas o gestor'; end if;
  return query select public.pront_publico(u) from public.usuarios u order by u.created_at;
end $$;

-- Cria (p_id nulo) ou edita um usuário. Senha definida pelo gestor é provisória.
create or replace function public.pront_salvar_usuario(p_token text, p_id uuid, p_nome text, p_login text, p_tipo text,
  p_crm text, p_conselho text, p_senha text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare g public.usuarios := public.pront_usuario_sessao(p_token); u public.usuarios;
begin
  if g.id is null or g.tipo <> 'gestor' then raise exception 'Apenas o gestor'; end if;
  if coalesce(trim(p_nome),'') = '' then raise exception 'Informe o nome'; end if;
  if p_tipo not in ('medico','recepcao','laboratorio') then raise exception 'Perfil inválido'; end if;
  if coalesce(p_senha,'') <> '' and length(p_senha) < 8 then raise exception 'A senha precisa ter pelo menos 8 caracteres'; end if;
  if p_id is null then
    if coalesce(trim(p_login),'') = '' then raise exception 'Informe o login'; end if;
    if coalesce(p_senha,'') = '' then raise exception 'Defina uma senha'; end if;
    insert into public.usuarios (nome, login, senha, senha_hash, trocar_senha, tipo, crm, conselho)
    values (trim(p_nome), lower(trim(p_login)), null, crypt(p_senha, gen_salt('bf')), true, p_tipo, nullif(trim(p_crm),''), nullif(p_conselho,''))
    returning * into u;
  else
    update public.usuarios set nome = trim(p_nome), tipo = p_tipo, crm = nullif(trim(p_crm),''), conselho = nullif(p_conselho,'')
    where id = p_id and tipo <> 'gestor' returning * into u;
    if u.id is null then raise exception 'Usuário não encontrado'; end if;
    if coalesce(p_senha,'') <> '' then
      update public.usuarios set senha_hash = crypt(p_senha, gen_salt('bf')), senha = null, trocar_senha = true
      where id = p_id returning * into u;
      delete from public.pront_sessoes where usuario_id = p_id;
    end if;
  end if;
  return public.pront_publico(u);
end $$;

create or replace function public.pront_status_usuario(p_token text, p_id uuid, p_ativo boolean) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare g public.usuarios := public.pront_usuario_sessao(p_token);
begin
  if g.id is null or g.tipo <> 'gestor' then raise exception 'Apenas o gestor'; end if;
  update public.usuarios set ativo = p_ativo where id = p_id and tipo <> 'gestor';
  if not p_ativo then delete from public.pront_sessoes where usuario_id = p_id; end if;
end $$;

revoke all on function public.pront_usuario_sessao(text), public.pront_senha_confere(public.usuarios, text),
  public.pront_publico(public.usuarios) from public, anon, authenticated;
revoke all on function public.pront_login(text,text,text), public.pront_logout(text), public.pront_trocar_senha(text,text,text),
  public.pront_listar_usuarios(text), public.pront_salvar_usuario(text,uuid,text,text,text,text,text,text),
  public.pront_status_usuario(text,uuid,boolean) from public;
grant execute on function public.pront_login(text,text,text), public.pront_logout(text), public.pront_trocar_senha(text,text,text),
  public.pront_listar_usuarios(text), public.pront_salvar_usuario(text,uuid,text,text,text,text,text,text),
  public.pront_status_usuario(text,uuid,boolean) to anon, authenticated;
