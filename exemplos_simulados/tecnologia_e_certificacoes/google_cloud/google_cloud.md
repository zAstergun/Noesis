# Google Cloud Certifications — Associate Cloud Engineer (ACE) & Professional Cloud Architect

> Guia de parâmetros para geração e correção de simulados pela IA — alinhado aos *Exam Guides* e amostras oficiais do **Google Cloud** (`cloud.google.com/learn/certification`).

---

## 1. Requisitos e Estrutura Oficial

| Certificação | Público e Escopo | Duração e Volume | Nota de Corte e Regras |
| :--- | :--- | :--- | :--- |
| **Associate Cloud Engineer (ACE)** | Implantação, operação diária via Console/`gcloud`, IAM, GKE e redes na prática | **2 horas** · 50–60 questões (múltipla escolha simples ou múltipla) | Score não numérico (**Pass/Fail**; ~70% recomendado) |
| **Professional Cloud Architect (PCA)** | Arquitetura corporativa, migração, confiabilidade, segurança e **Case Studies oficiais** | **2 horas** · 50–60 questões (incluindo ~20–30% vinculadas a *Case Studies*) | **Pass/Fail** |
| **Cloud Digital Leader (CDL)** | Fundamentos de nuvem, IA/Dados e transformação digital | **90 min** · 50–60 questões | **Pass/Fail** |

### Domínios Oficiais — Associate Cloud Engineer (ACE)
1. **Setting up a cloud solution environment** (~20%): Hierarquia Organização -> Pastas -> Projetos -> Recursos, Cloud Billing budgets/exports, ativação de APIs (`gcloud services enable`), configuração do SDK `gcloud config`.
2. **Planning and configuring a cloud solution** (~17.5%): Estimativa com Pricing Calculator, escolha de compute (Compute Engine vs. GKE vs. Cloud Run vs. Cloud Functions), escolha de dados (Cloud SQL vs. Spanner vs. Firestore vs. Bigtable vs. BigQuery) e Storage classes.
3. **Deploying and implementing a cloud solution** (~25%): Deploy de VMs, **GKE** (`gcloud container clusters`, deployments/services), Cloud Run, VPCs/subnets/Cloud NAT/Load Balancers e IaC (Terraform).
4. **Ensuring successful operation of a cloud solution** (~20%): Managed Instance Groups (MIG) com autoscaling, snapshots, backups, Cloud Logging/Monitoring/Trace, alertas e upgrades de clusters.
5. **Configuring access and security** (~17.5%): IAM Roles (Basic vs. Predefined vs. Custom), **Service Accounts** (princípio do menor privilégio), VPC Service Controls e logs de auditoria.

---

## 2. Lógica de Elaboração e Arquitetura dos Distratores

Os exames do Google Cloud aplicam consistentemente **"Google-Recommended Best Practices"** como critério de desempate entre duas soluções que tecnicamente funcionariam:

1. **Princípio do Menor Privilégio no IAM:** Qualquer alternativa que sugira atribuir *Basic Roles* (`Owner`, `Editor`, `Viewer`) em produção, ou criar e baixar **chaves JSON de Service Account** (*user-managed keys*) para colocar dentro de código/VMs, está **incorreta**. A resposta correta usa **Service Account dedicada anexada ao recurso**, **Workload Identity** (no GKE) ou **Workload Identity Federation** (externo).
2. **Hierarquia de Decisão de Banco de Dados e Storage:**
   - **Relacional regional** (OLTP, ACID) -> **Cloud SQL** (ou **AlloyDB**);
   - **Relacional global / escala horizontal massiva** -> **Cloud Spanner**;
   - **NoSQL chave-valor baixa latência / IoT / séries temporais (TB–PB)** -> **Bigtable**;
   - **NoSQL documentos / mobile / sync** -> **Firestore**;
   - **Data Warehouse analítico serverless SQL** -> **BigQuery**;
   - **Armazenamento de objetos** -> **Cloud Storage** (*Standard* [quente], *Nearline* [1x/30 dias], *Coldline* [1x/90 dias], *Archive* [1x/365 dias] — sempre respeitar duração mínima de retenção!).
3. **Compute — "Menor esforço operacional / Mais gerenciado":** Se o requisito pede executar containers HTTP stateless com escala a zero e mínimo overhead operacional -> **Cloud Run** (não um cluster GKE completo nem VMs no Compute Engine).
4. **Comandos `gcloud` no ACE:** Saber distinguir subcomandos reais (`gcloud compute instances create`, `gcloud config set project`, `gcloud iam service-accounts`, `gcloud storage cp` / antigo `gsutil`, `gcloud auth configure-docker` / Artifact Registry).

---

## 3. Exemplos Reais e Modelos Comentados (`cloud.google.com`)

### Exemplo 1 — ACE IAM & Service Accounts (Modelo Oficial Google Cloud)
> **Question:** You are managing a Google Cloud project that contains multiple Compute Engine instances. These instances need to write log files and backup data regularly into a specific Cloud Storage bucket named `company-backups-bucket`.  
> Following Google's security best practices, you want to grant the minimum necessary permissions for the instances to access this bucket without embedding permanent user credentials or service account keys into the instance metadata.  
> **What should you do?**  
> **A.** Create a dedicated custom service account, grant it `roles/storage.objectCreator` (or bucket-scoped `Storage Object Admin` if overwrite/list needed) on `company-backups-bucket`, and attach that service account to the Compute Engine instances.  
> **B.** Grant the `roles/storage.admin` role at the project level to the default Compute Engine service account.  
> **C.** Generate an HMAC/JSON key for a project owner, store the key in the instance startup script, and use it to authenticate API calls to Cloud Storage.  
> **D.** Use the predefined project-level `Editor` role for the default service account attached to each VM.  
>
> **Gabarito:** **A**  
> **Comentário:** **A** aplica perfeitamente o menor privilégio (Service Account dedicada + permissão limitada ao bucket específico + sem chaves estáticas no disco). **B** e **D** usam escopo amplo no projeto e a *default service account* (que por padrão costuma ter `Editor`); **C** cria risco crítico de vazamento de credencial estática.

### Exemplo 2 — Arquitetura de Dados & Custo (Padrão ACE/PCA)
> **Question:** Uma equipe precisa armazenar bilhões de leituras de sensores IoT por semana, consultando por chave `sensor_id#timestamp` com latência abaixo de 10 ms para um painel em tempo real, além de manter histórico de 2 anos em armazenamento frio acessado 1 vez por ano para auditoria. Qual combinação segue as práticas recomendadas do Google Cloud?  
> **A.** Cloud SQL para séries temporais em tempo real + Cloud Storage Standard para auditoria.  
> **B.** Cloud Bigtable para ingestão/leitura de baixa latência + Cloud Storage Archive para retenção anual de baixo custo.  
> **C.** BigQuery para consultas < 10 ms por registro + Firestore para arquivo de 2 anos.  
> **D.** Cloud Spanner para IoT + Cloud Storage Nearline para acesso anual.  
>
> **Gabarito:** **B** — **Bigtable** é o banco NoSQL colunar projetado para alta vazão IoT e latência sub-10ms; **Archive** tem menor custo por GB para acesso ≤ 1 vez/ano (enquanto *Nearline* cobra mais por armazenamento mensal para dados frios anuais).

---

## 4. Diretrizes Obrigatórias para a IA (Geração de Simulados)

1. **Aplique sempre o tripé Google Cloud nas respostas corretas:**
   - *Segurança:* Menor privilégio (sem `Owner/Editor`, sem JSON key exportada);
   - *Operação:* Serviços gerenciados/serverless preferidos sobre gerenciamento manual de VMs quando não houver restrição contrária;
   - *Custo:* Preemptible/Spot VMs para cargas tolerantes a falhas, Committed Use Discounts para base estável, Storage Lifecycle rules e BigQuery partitioning/clustering.
2. **Atualize nomes de serviços:** Prefira **Artifact Registry** (não *Container Registry*), **`gcloud storage`** (junto com menção a *gsutil* se relevante), e **Cloud Workstations / Cloud Deploy** quando aplicável.
3. **Para simulados de `Professional Cloud Architect (PCA)`:** Inclua blocos baseados em um **Case Study** (com *Company Overview, Solution Concept, Business Requirements, Technical Requirements*), cobrando trade-offs arquiteturais reais.
4. **No gabarito comentado:** Explique exatamente qual requisito do cenário (latência, custo, escopo IAM, conformidade ou esforço operacional) elimina cada um dos 3 distratores.
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Cloud Setup & Billing -> 2) Planning & Architecture -> 3) Deploying Solutions (GKE/Run/VMs) -> 4) Operations & Monitoring -> 5) IAM & Security), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
