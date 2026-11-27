# 🗄️ Supabase — Noesis Schema & Security Organization

Este diretório documenta e versiona o esquema PostgreSQL, políticas de **Row Level Security (RLS)**, funções RPC e configurações de **Realtime** do **Noesis** no ecossistema compartilhado **Aster**.

## Diretrizes Aplicadas
- **Prefixação Estrita (`noesis_*`)**: Nenhuma tabela ou função do Noesis usa nomes genéricos, preservando o isolamento com outros apps do ecossistema (`profiles`, `crm_apps`, `studioos_*`, `soulfighter_*`, `tunelab_*`).
- **RLS Ativo em 100% das Tabelas**: Todas as 9 tabelas `noesis_*` possuem `ROW LEVEL SECURITY` habilitado e restrito a `auth.uid()`.
- **Identidade Global**: Usuários autenticados usam `auth.users(id)` e `public.profiles`, com avatar armazenado no bucket `avatars` (`owner = auth.uid()`).

## Tabelas `noesis_*` (9/9 Ativas)

| Tabela | Chave Primária | Acesso RLS | Realtime | Finalidade |
| :--- | :--- | :--- | :---: | :--- |
| `public.noesis_sessions` | `id (uuid)` | `auth.uid() = user_id` | ✅ | Sessões de estudo e métricas do Tracker |
| `public.noesis_calendar_events` | `id (uuid)` | `auth.uid() = user_id` | ✅ | Agenda, blocos de foco, revisões e provas |
| `public.noesis_documents` | `id (uuid)` | `auth.uid() = user_id` | — | Documentos e provas para RAG |
| `public.noesis_quizzes` | `id (uuid)` | `auth.uid() = user_id` | — | Simulados, respostas e review IA |
| `public.noesis_roadmaps` | `id (uuid)` | `auth.uid() = user_id` | — | Trilhas de aprendizado por etapas |
| `public.noesis_flashcard_decks` | `(user_id, id)` | `auth.uid() = user_id` | — | Baralhos e cartões de revisão espaçada 3D |
| `public.noesis_study_notebooks` | `(user_id, id)` | `auth.uid() = user_id` | — | Cadernos e anotações em Markdown |
| `public.noesis_insight_ledger` | `(user_id, id)` | `auth.uid() = user_id` | — | Razão contábil da Economia de Insights (`✦`) |
| `public.noesis_study_groups` | `id (text)` | Líder ou membro (`noesis_is_study_group_member`) | — | Grupos colaborativos (entrada via RPC `noesis_join_study_group_by_code`) |

## Ordem das Migrations (`supabase/migrations/`)
1. `20261120081403_create_noesis_base_schema.sql` — Schema base (`noesis_sessions`, `noesis_calendar_events`, `noesis_documents`, `noesis_quizzes`) + RLS + catálogo `crm_apps`.
2. `20261124231642_add_saved_attempt_columns_to_noesis_quizzes.sql` — Colunas de tentativas salvas e review IA em `noesis_quizzes`.
3. `20261125001238_create_noesis_roadmaps_table.sql` — Tabela `noesis_roadmaps` + RLS + índice.
4. `20261125214519_grant_noesis_tables_and_enable_realtime.sql` — Grants DML e habilitação de `supabase_realtime`.
5. `20261127092600_create_missing_noesis_tables_and_rls.sql` — Criação das 4 tabelas complementares (`noesis_flashcard_decks`, `noesis_study_notebooks`, `noesis_insight_ledger`, `noesis_study_groups`), índices, RLS e RPC seguro de entrada por convite (`noesis_join_study_group_by_code`).
6. `20261127093000_revoke_anon_execute_on_noesis_join_study_group.sql` — Revoga `EXECUTE` de `PUBLIC`/`anon` na função `noesis_join_study_group_by_code`, liberando apenas para `authenticated` e `service_role`.
7. `20261127095800_harden_noesis_study_groups_security.sql` — Sanitiza `p_member` em `noesis_join_study_group_by_code` (impede escalação de `is_leader`/`is_vip`/permissões) e protege `leader_id` e `invite_code` contra alterações por membros não-líderes via trigger.
