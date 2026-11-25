# Exemplos e Parâmetros de Simulados (Base de Referência para IA)

Este diretório contém **guias de referência em Markdown (`.md`)** para **38 perfis de provas e certificações** brasileiras e internacionais, organizados por área temática e subpastas. Todos os arquivos de prova originais (PDFs) foram processados e removidos, permanecendo apenas os documentos estruturados com:

1. **Requisitos e Estrutura Oficial** (duração, número de questões, escalas, pesos e critérios de aprovação/TRI/penalização).
2. **Lógica de Elaboração e Arquitetura dos Distratores** (padrões cognitivos da banca, armadilhas típicas e estilo dos enunciados).
3. **Exemplos Reais e Modelos Comentados** (extraídos ou modelados a partir de cadernos e guias oficiais de cada instituição).
4. **Diretrizes Obrigatórias para a IA** (regras de geração de simulados fiéis e formato de correção/gabarito).

---

## Estrutura de Diretórios (7 Categorias · 38 Guias)

### 1. Vestibulares e Exames Nacionais do Brasil (`vestibulares_brasil/`)
- [ENEM](vestibulares_brasil/enem/enem.md) — INEP (4 áreas, Redação dissertativo-argumentativa, TRI)
- [FUVEST / USP](vestibulares_brasil/fuvest/fuvest.md) — 1ª e 2ª fases, obras obrigatórias e estilo analítico
- [UNICAMP](vestibulares_brasil/unicamp/unicamp.md) — Comvest (1ª e 2ª fases, gêneros textuais diversos na redação)
- [UNESP](vestibulares_brasil/unesp/unesp.md) — Vunesp (1ª fase objetiva + 2ª fase com questões discursivas)
- [ITA](vestibulares_brasil/ita/ita.md) — 1ª fase e 2ª fase dissertativa de alta exigência em Exatas
- [ENCCEJA](vestibulares_brasil/encceja/encceja.md) — INEP (Ensino Fundamental e Médio, TRI e Redação)

### 2. Exames Acadêmicos Internacionais (`internacionais/`)
- [SAT (Digital SAT)](internacionais/sat/sat.md) — College Board (Reading & Writing + Math adaptativo, 400–1600)
- [ACT (Enhanced ACT)](internacionais/act/act.md) — ACT, Inc. (English, Math, Reading, Science opcional, 4 opções, 1–36)
- [GRE General Test](internacionais/gre/gre.md) — ETS (Shorter GRE: AWA, Verbal TC/SE/RC e Quantitative Comparison, 130–170)
- [GMAT Focus Edition](internacionais/gmat/gmat.md) — GMAC (Quant, Verbal CR/RC, Data Insights com Data Sufficiency, 205–805)
- [LSAT](internacionais/lsat/lsat.md) — LSAC (Logical Reasoning ×2 + Reading Comprehension + LSAT Writing, 120–180)

### 3. Provas de Proficiência em Idiomas (`idiomas/`)
- [IELTS (Academic & General)](idiomas/ielts/ielts.md) — Listening, Reading (T/F/NG, Y/N/NG), Writing Task 1/2, Speaking (Band 0–9)
- [TOEFL iBT](idiomas/toefl/toefl.md) — ETS (Reading, Listening, Speaking, Writing Academic Discussion, 0–120)
- [Cambridge English (B2 First & C1 Advanced)](idiomas/cambridge_english/cambridge_english.md) — Use of English Partes 1–4, Reading Partes 5–8, Writing (Scale 140–210)
- [DELE (Espanhol — B1, B2, C1)](idiomas/dele/dele.md) — Instituto Cervantes (3 opções `a/b/c`, CL + EIE integrada a áudio)
- [DELF / DALF (Francês — B1, B2, C1)](idiomas/delf_dalf/delf_dalf.md) — France Éducation International (QCM, Essai B2, Synthèse + Essai C1)
- [Goethe-Zertifikat (Alemão — B1, B2, C1)](idiomas/goethe_zertifikat/goethe_zertifikat.md) — Goethe-Institut (Exame modular *Lesen, Hören, Schreiben, Sprechen*)
- [JLPT (Japonês — N5 a N1)](idiomas/jlpt/jlpt.md) — Japan Foundation & JEES (Kanji, Vocabulário, Ordenação `[ ★ ]`, Gramática e Leitura)
- [HSK (Mandarim — Níveis 1 a 6)](idiomas/hsk/hsk.md) — Hanban / CTI (Chinês Simplificado, transição de Pinyin no HSK 3->4, 病句 no HSK 6)
- [Celpe-Bras (Português para Estrangeiros)](idiomas/celpe_bras/celpe_bras.md) — INEP (4 Tarefas comunicativas orientadas a gêneros + Parte Oral)

### 4. Tecnologia, Cloud, Segurança & Olimpíadas de Computação (`tecnologia_e_certificacoes/`)
- [POSCOMP](tecnologia_e_certificacoes/poscomp/poscomp.md) — SBC (Matemática, Fundamentos da Computação, Tecnologia)
- [ENADE Computação](tecnologia_e_certificacoes/enade_computacao/enade_computacao.md) — INEP (Formação Geral + Componente Específico CC/EC/SI/ES)
- [AWS & Certificações Cloud Base](tecnologia_e_certificacoes/cloud_e_certificacoes/cloud_e_certificacoes.md) — AWS SAA-C03 / CLF-C02 e arquitetura multi-domínio
- [CompTIA Security+ (SY0-701) & OWASP Top 10](tecnologia_e_certificacoes/comptia_security_plus/comptia_security_plus.md) — Domínios SY0-701, controles, logs SOC e PBQs
- [Kubernetes CNCF (CKA / CKAD / CKS)](tecnologia_e_certificacoes/kubernetes_cncf/kubernetes_cncf.md) — Linux Foundation / CNCF (`cncf/curriculum`, provas práticas `kubectl` & YAML)
- [Microsoft Azure (AZ-900 / AZ-104)](tecnologia_e_certificacoes/microsoft_azure/microsoft_azure.md) — Microsoft Learn (Entra ID, RBAC/Locks, VNets, Storage, Yes/No e Case Study)
- [Google Cloud (Associate Cloud Engineer / PCA)](tecnologia_e_certificacoes/google_cloud/google_cloud.md) — GCP (IAM/Service Accounts, GKE/Cloud Run, `gcloud`, BigQuery/Bigtable)
- [Cisco CCNA (200-301 v1.1)](tecnologia_e_certificacoes/cisco_ccna/cisco_ccna.md) — Switching/VLANs, STP, Longest Prefix Match, OSPF, CLI Cisco IOS e Automação
- [OBI (Olimpíada Brasileira de Informática)](tecnologia_e_certificacoes/obi/obi.md) — SBC/UNICAMP (Modalidade Iniciação lógica + Programação competitiva com subtarefas)

### 5. Jurídico e Concursos Públicos (`juridico_e_concursos/`)
- [OAB — Exame de Ordem Unificado](juridico_e_concursos/oab/oab.md) — FGV / CFOAB (1ª Fase 80 Qs + 2ª Fase Peça Prático-Profissional)
- [ENADE Direito](juridico_e_concursos/enade_direito/enade_direito.md) — INEP (Formação Geral + Eixo Jurídico e Asserção-Razão)
- [Concursos Públicos Brasileiros](juridico_e_concursos/concursos_publicos/concursos_publicos.md) — Cebraspe (Certo/Errado 1:1), FGV (casos concretos e semântica) e Cesgranrio/CNU
- [ENAM — Exame Nacional da Magistratura](juridico_e_concursos/enam/enam.md) — ENFAM / FGV (80 Qs em 8 ramos, corte 70%/50%, STF/STJ e Formação Humanística)

### 6. Saúde e Medicina (`saude_e_medicina/`)
- [REVALIDA](saude_e_medicina/revalida/revalida.md) — INEP (1ª Fase objetiva + discursivas; 2ª Fase estações práticas OSCE)
- [USMLE (Step 1 & Step 2 CK)](saude_e_medicina/usmle/usmle.md) — NBME / FSMB (vinhetas clínicas sem *buzzwords*, mecanismos e *next step in management*)
- [ENARE (Residência Médica e Multiprofissional)](saude_e_medicina/enare/enare.md) — Ebserh / FGV (5 Grandes Áreas, protocolos MS/PCDT e casos clínicos)

### 7. Negócios, Finanças e Economia (`negocios_financas_e_economia/`)
- [ANBIMA (CPA, C-Pro R, C-Pro I) & CFA Level I](negocios_financas_e_economia/anbima_e_cfa/anbima_e_cfa.md) — Mercado financeiro BR (CVM 175, Suitability/PLDFT, IR/IOF) + CFA Institute (3 opções + Ethics)
- [ANPEC (Pós-Graduação em Economia)](negocios_financas_e_economia/anpec/anpec.md) — Itens `0–4` (`V/F` com fator de correção), Macro, Micro, Matemática, Estatística e Economia Brasileira
