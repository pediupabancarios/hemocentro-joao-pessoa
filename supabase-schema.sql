-- ==========================================================
-- Hemocentro João Pessoa — Schema Supabase (v3)
-- Reflete TODAS as tabelas usadas pelo index.html:
-- pacientes, receitas, solicitacoes_exames, solicitacoes_hemocomponentes,
-- usuarios, medico_dias_atendimento, agendamentos, anexos (+ Storage).
--
-- Pode rodar este script várias vezes sem quebrar nada:
-- todos os comandos são idempotentes (create ... if not exists,
-- alter ... add column if not exists, drop policy if exists, etc.).
-- ==========================================================

create extension if not exists "pgcrypto";

-- ==========================================================
-- 1. Pacientes
-- ==========================================================
create table if not exists pacientes (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  prontuario text,
  nascimento date,
  sexo text,
  telefone text,
  cpf text,
  sus text,
  endereco text,       -- endereço completo montado (compatibilidade / exibição)
  logradouro text,      -- rua / avenida
  numero text,          -- número separado do logradouro
  bairro text,
  cidade text,
  uf text,
  cep text,
  tipo_sanguineo text,
  raca_cor text,        -- Branca / Preta / Parda / Amarela / Indígena
  nome_mae text,
  alergias text,
  diagnostico text,
  convenio text,
  created_at timestamptz default now()
);
alter table pacientes add column if not exists logradouro text;
alter table pacientes add column if not exists numero text;
alter table pacientes add column if not exists bairro text;
alter table pacientes add column if not exists cidade text;
alter table pacientes add column if not exists uf text;
alter table pacientes add column if not exists cep text;
alter table pacientes add column if not exists raca_cor text;
alter table pacientes add column if not exists nome_mae text;

-- ==========================================================
-- 2. Receitas Médicas (F.CP.107.04 / F.CP.107.05)
-- ==========================================================
create table if not exists receitas (
  id uuid primary key default gen_random_uuid(),
  paciente_id uuid references pacientes(id) on delete cascade,
  paciente_nome text not null default 'MARIA DA CONCEIÇÃO SILVA',
  data date not null default current_date,
  tipo text not null default 'Receituário médico',
  medicamento text not null,
  uso text,
  via text,             -- Oral / EV / IM / SC / Inalatório
  prescricao text,
  medico text default 'Dr. Rodrigo Cahuana',
  created_at timestamptz default now()
);
alter table receitas add column if not exists paciente_id uuid references pacientes(id) on delete cascade;
alter table receitas add column if not exists via text;

-- ==========================================================
-- 3. Solicitações de Exames (F.CP.107.02) — inclui resultado
-- ==========================================================
create table if not exists solicitacoes_exames (
  id uuid primary key default gen_random_uuid(),
  paciente_id uuid references pacientes(id) on delete cascade,
  paciente_nome text not null default 'MARIA DA CONCEIÇÃO SILVA',
  data date not null default current_date,
  previsao date,
  exame text not null,
  situacao text not null default 'Pendente',
  medico text default 'Dr. Rodrigo Cahuana',
  -- Resultado (registrado pelo laboratório)
  resultado text,
  formato_resultado text default 'tabela',   -- 'tabela' | 'texto'
  parametros_json text,                       -- JSON [{parametro,resultado,unidade,referencia}]
  categoria_laboratorio text,
  registro_numero text,
  observacoes_resultado text,
  responsavel_laboratorio text,
  responsavel_registro text,                  -- CRF / CRBM
  data_resultado date,
  created_at timestamptz default now()
);
alter table solicitacoes_exames add column if not exists paciente_id uuid references pacientes(id) on delete cascade;
alter table solicitacoes_exames add column if not exists resultado text;
alter table solicitacoes_exames add column if not exists formato_resultado text default 'tabela';
alter table solicitacoes_exames add column if not exists parametros_json text;
alter table solicitacoes_exames add column if not exists categoria_laboratorio text;
alter table solicitacoes_exames add column if not exists registro_numero text;
alter table solicitacoes_exames add column if not exists observacoes_resultado text;
alter table solicitacoes_exames add column if not exists responsavel_laboratorio text;
alter table solicitacoes_exames add column if not exists responsavel_registro text;
alter table solicitacoes_exames add column if not exists data_resultado date;

-- ==========================================================
-- 4. Solicitações de Hemocomponentes (F.CP.107.03)
-- ==========================================================
create table if not exists solicitacoes_hemocomponentes (
  id uuid primary key default gen_random_uuid(),
  paciente_id uuid references pacientes(id) on delete cascade,
  paciente_nome text not null default 'MARIA DA CONCEIÇÃO SILVA',
  data date not null default current_date,
  tipo text not null,
  quantidade text not null,
  urgencia text default 'Transfusão Programada',
  diagnostico text,
  situacao text not null default 'Pendente',
  medico text default 'Dr. Rodrigo Cahuana',
  hemoglobina text,
  hematocrito text,
  plaquetas text,
  peso text,
  coagulacao text,
  cirurgia text,
  created_at timestamptz default now()
);
alter table solicitacoes_hemocomponentes add column if not exists paciente_id uuid references pacientes(id) on delete cascade;
alter table solicitacoes_hemocomponentes add column if not exists hemoglobina text;
alter table solicitacoes_hemocomponentes add column if not exists hematocrito text;
alter table solicitacoes_hemocomponentes add column if not exists plaquetas text;
alter table solicitacoes_hemocomponentes add column if not exists peso text;
alter table solicitacoes_hemocomponentes add column if not exists coagulacao text;
alter table solicitacoes_hemocomponentes add column if not exists cirurgia text;

-- ==========================================================
-- 5. Usuários do sistema (login próprio — não usa Supabase Auth)
--    Perfis: gestor | medico | recepcao | laboratorio
-- ==========================================================
create table if not exists usuarios (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  login text not null unique,
  senha text not null,          -- texto puro (uso interno) — migrar p/ Auth antes de produção
  tipo text not null default 'medico',
  crm text,
  ativo boolean not null default true,
  created_at timestamptz default now()
);
alter table usuarios add column if not exists crm text;
alter table usuarios add column if not exists ativo boolean not null default true;

-- ==========================================================
-- 6. Dias de atendimento de cada médico (base da agenda)
--    dia_semana: 0=Domingo ... 6=Sábado
-- ==========================================================
create table if not exists medico_dias_atendimento (
  id uuid primary key default gen_random_uuid(),
  medico_id uuid references usuarios(id) on delete cascade,
  dia_semana integer not null check (dia_semana >= 0 and dia_semana <= 6)
);
create unique index if not exists medico_dias_atendimento_unico
  on medico_dias_atendimento (medico_id, dia_semana);

-- ==========================================================
-- 7. Agendamentos (6 vagas de manhã + 6 à tarde por médico/dia)
-- ==========================================================
create table if not exists agendamentos (
  id uuid primary key default gen_random_uuid(),
  medico_id uuid references usuarios(id) on delete cascade,
  medico_nome text,
  paciente_id uuid references pacientes(id) on delete set null,
  paciente_nome text,
  cpf text,
  data date not null,
  periodo text not null,        -- 'manha' | 'tarde'
  horario text not null,        -- '08:00' ... '15:30'
  status text default 'Agendado',   -- Agendado | Confirmado | Atendido | Cancelado
  observacoes text,
  criado_por text,
  created_at timestamptz default now()
);
alter table agendamentos add column if not exists cpf text;
-- impede dois agendamentos no mesmo horário do mesmo médico (ignora cancelados) -> erro 23505 tratado no app
create unique index if not exists agendamentos_slot_unico
  on agendamentos (medico_id, data, horario)
  where status <> 'Cancelado';

-- ==========================================================
-- 8. Anexos do paciente (arquivos no Storage, metadados aqui)
-- ==========================================================
create table if not exists anexos (
  id uuid primary key default gen_random_uuid(),
  paciente_id uuid references pacientes(id) on delete cascade,
  paciente_nome text,
  nome_arquivo text not null,
  caminho text not null,        -- caminho dentro do bucket 'anexos'
  tipo_arquivo text,
  tamanho_kb numeric,
  descricao text,
  enviado_por text,
  created_at timestamptz default now()
);

-- ==========================================================
-- 9. Storage — bucket 'anexos'
-- ==========================================================
insert into storage.buckets (id, name, public)
values ('anexos', 'anexos', true)
on conflict (id) do nothing;

drop policy if exists "anexos storage - leitura" on storage.objects;
drop policy if exists "anexos storage - escrita" on storage.objects;
drop policy if exists "anexos storage - atualizacao" on storage.objects;
drop policy if exists "anexos storage - exclusao" on storage.objects;
create policy "anexos storage - leitura"     on storage.objects for select using (bucket_id = 'anexos');
create policy "anexos storage - escrita"     on storage.objects for insert with check (bucket_id = 'anexos');
create policy "anexos storage - atualizacao" on storage.objects for update using (bucket_id = 'anexos') with check (bucket_id = 'anexos');
create policy "anexos storage - exclusao"    on storage.objects for delete using (bucket_id = 'anexos');

-- ==========================================================
-- Row Level Security
-- IMPORTANTE: o app usa tela de login própria (não o Auth do
-- Supabase), então estas políticas liberam acesso pela chave
-- "anon". Aceitável para uso interno/demonstração — para dados
-- reais de pacientes (sensíveis pela LGPD), o recomendado é
-- migrar para Supabase Auth + políticas por usuário/perfil.
-- ==========================================================
alter table pacientes                     enable row level security;
alter table receitas                      enable row level security;
alter table solicitacoes_exames           enable row level security;
alter table solicitacoes_hemocomponentes  enable row level security;
alter table usuarios                      enable row level security;
alter table medico_dias_atendimento       enable row level security;
alter table agendamentos                  enable row level security;
alter table anexos                        enable row level security;

drop policy if exists "allow all - pacientes"          on pacientes;
drop policy if exists "allow all - receitas"           on receitas;
drop policy if exists "allow all - exames"             on solicitacoes_exames;
drop policy if exists "allow all - hemocomponentes"    on solicitacoes_hemocomponentes;
drop policy if exists "allow all - usuarios"           on usuarios;
drop policy if exists "allow all - dias_atendimento"   on medico_dias_atendimento;
drop policy if exists "allow all - agendamentos"       on agendamentos;
drop policy if exists "allow all - anexos"             on anexos;

create policy "allow all - pacientes"        on pacientes                    for all using (true) with check (true);
create policy "allow all - receitas"         on receitas                     for all using (true) with check (true);
create policy "allow all - exames"           on solicitacoes_exames          for all using (true) with check (true);
create policy "allow all - hemocomponentes"  on solicitacoes_hemocomponentes for all using (true) with check (true);
create policy "allow all - usuarios"         on usuarios                     for all using (true) with check (true);
create policy "allow all - dias_atendimento" on medico_dias_atendimento      for all using (true) with check (true);
create policy "allow all - agendamentos"     on agendamentos                 for all using (true) with check (true);
create policy "allow all - anexos"           on anexos                       for all using (true) with check (true);

-- ==========================================================
-- Usuários de teste (só cria se o login ainda não existir).
-- O Gestor de demonstração (hemocentro / 1234) é embutido no
-- index.html e funciona mesmo sem linha na tabela.
-- ==========================================================
insert into usuarios (nome, login, senha, tipo, crm) values
  ('Dr. Rodrigo Cahuana',            'rodrigo',     '1234', 'medico',      'CRM-PB 12345'),
  ('Recepção',                       'recepcao',    '1234', 'recepcao',    null),
  ('Laboratório',                    'laboratorio', '1234', 'laboratorio', null)
on conflict (login) do nothing;

-- ==========================================================
-- Dados de exemplo — só semeia se a tabela pacientes ainda
-- estiver vazia (seguro rodar o script mais de uma vez)
-- ==========================================================
do $$
declare
  v_id uuid;
begin
  if not exists (select 1 from pacientes) then

    insert into pacientes (nome, prontuario, nascimento, sexo, telefone, cpf, sus, endereco, logradouro, numero, bairro, cidade, uf, cep, tipo_sanguineo, raca_cor, nome_mae, alergias, diagnostico, convenio)
    values ('MARIA DA CONCEIÇÃO SILVA','00012345','1985-06-15','Feminino','(83) 98765-4321','123.456.789-09','8980 1234 5678 9012','Rua das Flores, 123 — Bairro dos Estados — João Pessoa - PB — CEP: 58030-000','Rua das Flores','123','Bairro dos Estados','João Pessoa','PB','58030-000','A+','Parda','ANTONIA CONCEIÇÃO SILVA','Dipirona','Anemia Falciforme (HbSS)','SUS')
    returning id into v_id;

    insert into receitas (paciente_id, paciente_nome, data, tipo, medicamento, uso, via, prescricao, medico) values
    (v_id,'MARIA DA CONCEIÇÃO SILVA','2025-05-02','Receituário médico','Ácido Fólico 5 mg','1 comprimido ao dia','Oral','Ácido Fólico 5 mg — tomar 1 comprimido ao dia, via oral, uso contínuo.','Dr. Rodrigo Cahuana'),
    (v_id,'MARIA DA CONCEIÇÃO SILVA','2025-05-02','Receituário de controle especial','Hidroxiureia 500 mg','2 cápsulas ao dia','Oral','Hidroxiureia 500 mg — tomar 2 cápsulas ao dia, via oral, uso contínuo. Retorno em 30 dias para hemograma de controle.','Dr. Rodrigo Cahuana'),
    (v_id,'MARIA DA CONCEIÇÃO SILVA','2025-03-12','Receituário de controle especial','Deferasirox 360 mg','1 comprimido ao dia','Oral','Deferasirox 360 mg — tomar 1 comprimido ao dia, via oral, em jejum. Uso contínuo conforme protocolo de quelação de ferro.','Dr. Rodrigo Cahuana');

    insert into solicitacoes_exames (paciente_id, paciente_nome, data, previsao, exame, situacao, medico) values
    (v_id,'MARIA DA CONCEIÇÃO SILVA','2025-05-02', null, 'Hemograma Completo', 'Pendente', 'Dr. Rodrigo Cahuana'),
    (v_id,'MARIA DA CONCEIÇÃO SILVA','2025-05-02', null, 'Ferritina', 'Pendente', 'Dr. Rodrigo Cahuana'),
    (v_id,'MARIA DA CONCEIÇÃO SILVA','2025-03-12', null, 'Função Hepática (TGO, TGP)', 'Concluído', 'Dr. Rodrigo Cahuana');

    insert into solicitacoes_hemocomponentes (paciente_id, paciente_nome, data, tipo, quantidade, urgencia, diagnostico, situacao, medico) values
    (v_id,'MARIA DA CONCEIÇÃO SILVA','2025-05-02', 'Concentrado de Hemácias', '2 bolsas', 'Transfusão Programada', 'Anemia Falciforme (HbSS)', 'Autorizada', 'Dr. Rodrigo Cahuana');

  end if;
end $$;

-- ==========================================================
-- Se você rodou uma versão antiga do script (sem pacientes) e
-- tem receitas/exames/hemocomponentes "órfãos" (sem paciente_id),
-- este bloco vincula automaticamente à Maria:
-- ==========================================================
do $$
declare
  v_maria uuid;
begin
  select id into v_maria from pacientes where nome = 'MARIA DA CONCEIÇÃO SILVA' limit 1;
  if v_maria is not null then
    update receitas                     set paciente_id = v_maria where paciente_id is null;
    update solicitacoes_exames          set paciente_id = v_maria where paciente_id is null;
    update solicitacoes_hemocomponentes set paciente_id = v_maria where paciente_id is null;
  end if;
end $$;
