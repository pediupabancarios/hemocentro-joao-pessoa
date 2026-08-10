-- ==========================================================
-- Hemocentro João Pessoa — Schema Supabase (v2 — com pacientes)
-- Pode rodar este script mesmo que já tenha rodado a v1 antes:
-- todos os comandos são seguros para repetir (idempotentes).
-- ==========================================================

create extension if not exists "pgcrypto";

-- ---------- Pacientes ----------
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
  logradouro text,      -- rua e número
  bairro text,
  cidade text,
  uf text,
  cep text,
  tipo_sanguineo text,
  alergias text,
  diagnostico text,
  convenio text,
  created_at timestamptz default now()
);
alter table pacientes add column if not exists logradouro text;
alter table pacientes add column if not exists bairro text;
alter table pacientes add column if not exists cidade text;
alter table pacientes add column if not exists uf text;
alter table pacientes add column if not exists cep text;
alter table pacientes add column if not exists raca_cor text; -- Branca / Preta / Parda / Amarela / Indígena

-- ---------- Receitas Médicas (F.CP.107.04 / F.CP.107.05) ----------
create table if not exists receitas (
  id uuid primary key default gen_random_uuid(),
  paciente_id uuid references pacientes(id) on delete cascade,
  paciente_nome text not null default 'MARIA DA CONCEIÇÃO SILVA',
  data date not null default current_date,
  tipo text not null default 'Receituário médico',
  medicamento text not null,
  uso text,
  prescricao text,
  medico text default 'Dr. Rodrigo Cahuana',
  created_at timestamptz default now()
);
alter table receitas add column if not exists paciente_id uuid references pacientes(id);

-- ---------- Solicitações de Exames (F.CP.107.02) ----------
create table if not exists solicitacoes_exames (
  id uuid primary key default gen_random_uuid(),
  paciente_id uuid references pacientes(id) on delete cascade,
  paciente_nome text not null default 'MARIA DA CONCEIÇÃO SILVA',
  data date not null default current_date,
  previsao date,
  exame text not null,
  situacao text not null default 'Pendente',
  medico text default 'Dr. Rodrigo Cahuana',
  created_at timestamptz default now()
);
alter table solicitacoes_exames add column if not exists paciente_id uuid references pacientes(id);

-- ---------- Solicitações de Hemocomponentes (F.CP.107.03) ----------
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
  created_at timestamptz default now()
);
alter table solicitacoes_hemocomponentes add column if not exists paciente_id uuid references pacientes(id);
alter table solicitacoes_hemocomponentes add column if not exists hemoglobina text;
alter table solicitacoes_hemocomponentes add column if not exists hematocrito text;
alter table solicitacoes_hemocomponentes add column if not exists plaquetas text;
alter table solicitacoes_hemocomponentes add column if not exists peso text;
alter table solicitacoes_hemocomponentes add column if not exists coagulacao text;
alter table solicitacoes_hemocomponentes add column if not exists cirurgia text;

-- ==========================================================
-- Row Level Security
-- IMPORTANTE: como o app usa uma tela de login própria (não o
-- Auth do Supabase), estas políticas liberam acesso à chave
-- "anon". Aceitável para uso interno/demonstração — para dados
-- reais de pacientes (dado sensível pela LGPD), o recomendado
-- é migrar para Supabase Auth + políticas por usuário/perfil
-- antes de usar em produção com pacientes de verdade.
-- ==========================================================
alter table pacientes enable row level security;
alter table receitas enable row level security;
alter table solicitacoes_exames enable row level security;
alter table solicitacoes_hemocomponentes enable row level security;

drop policy if exists "allow all - pacientes" on pacientes;
drop policy if exists "allow all - receitas" on receitas;
drop policy if exists "allow all - exames" on solicitacoes_exames;
drop policy if exists "allow all - hemocomponentes" on solicitacoes_hemocomponentes;

create policy "allow all - pacientes" on pacientes for all using (true) with check (true);
create policy "allow all - receitas" on receitas for all using (true) with check (true);
create policy "allow all - exames" on solicitacoes_exames for all using (true) with check (true);
create policy "allow all - hemocomponentes" on solicitacoes_hemocomponentes for all using (true) with check (true);

-- ==========================================================
-- Dados de exemplo — só semeia se a tabela pacientes ainda
-- estiver vazia (seguro rodar o script mais de uma vez)
-- ==========================================================
do $$
declare
  v_id uuid;
begin
  if not exists (select 1 from pacientes) then

    insert into pacientes (nome, prontuario, nascimento, sexo, telefone, cpf, sus, endereco, logradouro, bairro, cidade, uf, cep, tipo_sanguineo, raca_cor, alergias, diagnostico, convenio)
    values ('MARIA DA CONCEIÇÃO SILVA','00012345','1985-06-15','Feminino','(83) 98765-4321','123.456.789-09','8980 1234 5678 9012','Rua das Flores, 123 — Bairro dos Estados — João Pessoa - PB — CEP: 58030-000','Rua das Flores, 123','Bairro dos Estados','João Pessoa','PB','58030-000','A+','Parda','Dipirona','Anemia Falciforme (HbSS)','SUS')
    returning id into v_id;

    insert into receitas (paciente_id, paciente_nome, data, tipo, medicamento, uso, prescricao, medico) values
    (v_id,'MARIA DA CONCEIÇÃO SILVA','2025-05-02','Receituário médico','Ácido Fólico 5 mg','1 comprimido ao dia','Ácido Fólico 5 mg — tomar 1 comprimido ao dia, via oral, uso contínuo.','Dr. Rodrigo Cahuana'),
    (v_id,'MARIA DA CONCEIÇÃO SILVA','2025-05-02','Receituário de controle especial','Hidroxiureia 500 mg','2 cápsulas ao dia','Hidroxiureia 500 mg — tomar 2 cápsulas ao dia, via oral, uso contínuo. Retorno em 30 dias para hemograma de controle.','Dr. Rodrigo Cahuana'),
    (v_id,'MARIA DA CONCEIÇÃO SILVA','2025-03-12','Receituário de controle especial','Deferasirox 360 mg','1 comprimido ao dia','Deferasirox 360 mg — tomar 1 comprimido ao dia, via oral, em jejum. Uso contínuo conforme protocolo de quelação de ferro.','Dr. Rodrigo Cahuana');

    insert into solicitacoes_exames (paciente_id, paciente_nome, data, previsao, exame, situacao, medico) values
    (v_id,'MARIA DA CONCEIÇÃO SILVA','2025-05-02', null, 'Hemograma Completo', 'Pendente', 'Dr. Rodrigo Cahuana'),
    (v_id,'MARIA DA CONCEIÇÃO SILVA','2025-05-02', null, 'Ferritina', 'Pendente', 'Dr. Rodrigo Cahuana'),
    (v_id,'MARIA DA CONCEIÇÃO SILVA','2025-03-12', null, 'Função Hepática (TGO, TGP)', 'Concluído', 'Dr. Rodrigo Cahuana');

    insert into solicitacoes_hemocomponentes (paciente_id, paciente_nome, data, tipo, quantidade, urgencia, diagnostico, situacao, medico) values
    (v_id,'MARIA DA CONCEIÇÃO SILVA','2025-05-02', 'Concentrado de Hemácias', '2 bolsas', 'Transfusão Programada', 'Anemia Falciforme (HbSS)', 'Autorizada', 'Dr. Rodrigo Cahuana');

  end if;
end $$;

-- ==========================================================
-- Se você já tinha rodado a v1 do script (sem pacientes) e já
-- tem receitas/exames/hemocomponentes "órfãos" (sem paciente_id),
-- este bloco vincula automaticamente à Maria:
-- ==========================================================
do $$
declare
  v_maria uuid;
begin
  select id into v_maria from pacientes where nome = 'MARIA DA CONCEIÇÃO SILVA' limit 1;
  if v_maria is not null then
    update receitas set paciente_id = v_maria where paciente_id is null;
    update solicitacoes_exames set paciente_id = v_maria where paciente_id is null;
    update solicitacoes_hemocomponentes set paciente_id = v_maria where paciente_id is null;
  end if;
end $$;
