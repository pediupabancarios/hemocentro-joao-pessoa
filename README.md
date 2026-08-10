# Hemocentro João Pessoa — Prontuário Eletrônico

Aplicativo web single-page (HTML/CSS/JS puro) para gestão de pacientes, receitas médicas,
solicitações de exames laboratoriais e de hemocomponentes do Hemocentro João Pessoa,
reproduzindo os formulários oficiais (F.CP.107.02, F.CP.107.03, F.CP.107.04, F.CP.107.05 e BPA-1).

## Funcionalidades

- Login com 3 perfis: **Gestor**, **Médico** e **Recepção**, cada um com permissões diferentes
- Cadastro de pacientes com endereço completo, raça/cor, tipo sanguíneo etc.
- Receituário Médico e Receituário de Controle Especial (impressão fiel ao modelo oficial)
- Solicitação de Exames com checklist de múltipla escolha (uma única folha, mesmo com vários exames marcados)
- Solicitação de Hemocomponentes, incluindo dados clínicos e laboratoriais (Hemoglobina, Hematócrito, Plaquetas etc.)
- Impressão do **BPA-1** (Boletim de Produção Ambulatorial) já preenchido com os dados do paciente
- Edição e exclusão de qualquer solicitação já criada
- Persistência de dados via [Supabase](https://supabase.com) (Postgres)

## Como rodar

Este é um app estático — basta abrir o `index.html` em qualquer navegador. Não precisa de
servidor, build ou instalação de dependências.

## Configuração do banco (Supabase)

1. Crie um projeto gratuito em [supabase.com](https://supabase.com)
2. Rode o arquivo `supabase-schema.sql` no **SQL Editor** do projeto (é seguro rodar mais de uma vez)
3. Em **Project Settings → API**, copie a **Project URL** e a chave **anon public**
4. Cole os dois valores no início do `<script>` do `index.html`:

```js
const SUPABASE_URL = "https://SEU-PROJETO.supabase.co";
const SUPABASE_ANON_KEY = "sua-chave-anon-aqui";
```

Sem essa configuração, o app funciona em "modo demonstração" (dados de exemplo somem ao
fechar a aba).

## Publicando o site (Netlify)

Arraste a pasta/arquivo em [app.netlify.com/drop](https://app.netlify.com/drop) — não precisa
de conta para testar, e é gratuito para manter no ar.

## Login de demonstração

| Perfil | Login | Senha |
|---|---|---|
| Gestor | `hemocentro` | `1234` |

O Gestor pode cadastrar médicos e recepcionistas na tela **Usuários**.

## ⚠️ Aviso de segurança

Este projeto foi construído para uso interno/demonstração. As senhas dos usuários e os dados
dos pacientes ficam acessíveis via chave pública (`anon key`) do Supabase, sem autenticação
real (Supabase Auth) nem criptografia de senha. **Antes de usar com pacientes e dados reais em
produção**, recomenda-se:

- Migrar o login para Supabase Auth (ou outro provedor de autenticação real)
- Criptografar as senhas armazenadas
- Revisar as políticas de Row Level Security (RLS) das tabelas para restringir acesso por perfil

## Estrutura de arquivos

```
index.html            → aplicativo completo (HTML + CSS + JS em um único arquivo)
supabase-schema.sql   → script de criação das tabelas no Supabase (idempotente)
```
