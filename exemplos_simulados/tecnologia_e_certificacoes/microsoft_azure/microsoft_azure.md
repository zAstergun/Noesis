# Microsoft Azure Certifications — AZ-900 (Fundamentals) & AZ-104 (Administrator)

> Guia de parâmetros para geração e correção de simulados pela IA — alinhado às guias de estudo oficiais e *Practice Assessments* do **Microsoft Learn** (`learn.microsoft.com`).

---

## 1. Requisitos e Estrutura Oficial

Os exames Microsoft Azure utilizam pontuação escalonada de **1 a 1.000 pontos**, com **nota mínima de aprovação fixa em 700 / 1.000** (sem penalidade por erro; respostas corretas em questões multipartes dão crédito parcial).

| Exame | Nível e Foco | Duração e Volume | Domínios Oficiais e Pesos |
| :--- | :--- | :--- | :--- |
| **AZ-900** (*Azure Fundamentals*) | Fundamentos de nuvem, serviços centrais Azure e governança/preços | **45 min** · 40–60 questões | Cloud Concepts (**25–30%**) · Azure Architecture & Services (**35–40%**) · Azure Management & Governance (**30–35%**) |
| **AZ-104** (*Azure Administrator Associate*) | Operação diária: identidades, governança, storage, compute e redes virtuais | **100 min** (+20 min leitura) · 40–60 questões + **Case Study** | Identities & Governance (**20–25%**) · Storage (**15–20%**) · Compute Resources (**20–25%**) · Virtual Networking (**15–20%**) · Monitor & Maintain (**10–15%**) |

### Formatos Típicos de Questões Microsoft
- **Single/Multiple Choice** (`Choose two` / `Choose three`)
- **Case Study (Estudo de Caso — AZ-104):** Cenário corporativo longo dividido em abas (*Existing Environment, Requirements, Technical Constraints*) com 4–8 questões vinculadas.
- **Yes / No Sequence (Série sem voltar atrás):** 3 questões consecutivas sobre o mesmo problema apresentando soluções distintas; não permite voltar para alterar a resposta após avançar!
- **Active Screen / Hot Area (Dropdowns):** Completar blocos de JSON (ARM/Bicep), PowerShell (`Az`), Azure CLI (`az`) ou regras de NSG escolhendo opções em menus suspensos.

---

## 2. Lógica de Elaboração e Arquitetura dos Distratores

1. **Armadilha de RBAC vs. Resource Locks vs. Azure Policy (AZ-104):**
   - **RBAC (IAM):** Controla *quem* pode fazer *o quê* em um escopo.
   - **Resource Lock (`CanNotDelete` vs. `ReadOnly`):** Impede exclusão/alteração acidental **até por um `Owner` ou `Global Admin`** enquanto o bloqueio estiver ativo. Distratores propõem `ReadOnly` quando a operação ainda precisa gravar dados no recurso!
   - **Azure Policy:** Garante conformidade de configuração (ex.: exigir tags, proibir criação de VMs caras ou regiões fora do Brasil/UE).
2. **Redes Virtuais, NSG e Peering:**
   - **VNet Peering** não é transitivo por padrão (*A <-> B* e *B <-> C* não conecta *A <-> C* sem *Gateway Transit* ou *NVA/Azure Route Server*).
   - **NSG (Network Security Group):** Prioridade numérica **menor vence primeiro** (100 prevalece sobre 200), e regras possuem `DenyAllInbound` no fim (prioridade 65500).
   - **Service Endpoints vs. Private Endpoints:** Service Endpoint mantém IP público no tráfego via backbone; **Private Endpoint** injeta um **IP privado da sua VNet** (exigido quando há conectividade on-premises VPN/ExpressRoute sem tráfego público).
3. **Storage Redundancy & Access Tiers:**
   - **LRS / ZRS / GRS / GZRS / RA-GRS:** Saber distinguir falha de rack/datacenter local (LRS), falha de Zona de Disponibilidade (ZRS) e falha regional com leitura na secundária (RA-GRS).
   - **Hot / Cool / Cold / Archive:** Dados em **Archive** estão offline e **precisam ser reidratados** antes de leitura (levando horas), além de terem penalidade de exclusão antecipada (180 dias).
4. **AZ-900 — CapEx vs. OpEx & IaaS/PaaS/SaaS & Modelos de Responsabilidade Compartilhada:** Distratores invertem responsabilidades do cliente vs. Microsoft (em SaaS o cliente só gerencia dados/identidades; em IaaS gerencia também OS/patching e firewall de rede).

---

## 3. Exemplos Reais e Modelos Comentados (Padrão Microsoft Learn)

### Exemplo 1 — AZ-104 Storage & Governance (Padrão Oficial Microsoft Learn)
> **Question:** Your company has a subscription that contains an Azure Storage account named `storedata1901`.  
> You need to ensure that Blob storage data can be recovered if it is accidentally deleted or overwritten, and you must protect against accidental deletions of the storage account itself. The solution must meet the following requirements:  
> - Retain deleted blobs for exactly 14 days.  
> - Prevent the deletion of the storage account resource, even if an administrator attempts to delete it.  
>
> **Which two actions should you perform? (Choose two.)**  
> **A.** Enable soft delete for blobs with a retention period of 14 days.  
> **B.** Enable soft delete for containers with a retention period of 14 days.  
> **C.** Create a new Azure Resource Manager (ARM) lock of type `ReadOnly` on the storage account.  
> **D.** Create a new Azure Resource Manager (ARM) lock of type `CanNotDelete` on the storage account.  
> **E.** Enable versioning for the storage account.  
>
> **Gabarito:** **A e D**  
> **Comentário:** **A** atende diretamente à retenção de 14 dias para blobs excluídos ou sobrescritos. **D** (`CanNotDelete`) impede remoção da conta de armazenamento mantendo leitura/escrita operacional (ao contrário de **C** `ReadOnly`, que quebraria gravações de aplicativos!).

### Exemplo 2 — AZ-104 Compute / Availability & Scale Sets
> **Question (Yes/No ou Dropdown):** Uma aplicação web stateless hospeda 4 VMs atrás de um Azure Load Balancer Standard. Para garantir SLA de **99,99%** protegendo contra falha de um datacenter inteiro dentro da mesma região, onde as VMs devem ser distribuídas?  
> **A.** Single Availability Set com 2 Fault Domains  
> **B.** Availability Zones (distribuídas entre Zonas 1, 2 e 3)  
> **C.** Azure Site Recovery entre duas sub-redes da mesma VNet  
> **D.** Proximity Placement Group na mesma zona  
> **Gabarito:** **B (Availability Zones)** — *Availability Set* protege contra falha de rack/hardware dentro de um mesmo datacenter (SLA 99,95%); *Availability Zones* protegem contra falha de datacenter inteiro na região (SLA 99,99%).

### Exemplo 3 — AZ-900 Cloud Concepts (CapEx vs. OpEx)
> **Statement:** *"Migrating an on-premises datacenter to Azure virtual machines shifts infrastructure spending from Capital Expenditure (CapEx) to Operational Expenditure (OpEx)."*  
> **Answer:** **Yes / True** — Compra prévia de servidores físicos é CapEx; consumo sob demanda (*pay-as-you-go*) é OpEx.

---

## 4. Diretrizes Obrigatórias para a IA (Geração de Simulados)

1. **Respeite a nomenclatura atualizada do Azure:** Use sempre **Microsoft Entra ID** (novo nome do antigo *Azure Active Directory*), **Azure Monitor**, **Azure RBAC**, **Azure Kubernetes Service (AKS)** e **Microsoft Defender for Cloud**.
2. **Varie os formatos nativos da Microsoft:** Além de múltipla escolha simples, gere questões **`Choose two/three`**, sequências **`Yes/No`**, preenchimento de **comandos `az` / PowerShell `New-Az...` / templates ARM-Bicep** e mini **Case Studies** (com tabela de requisitos + restrições).
3. **Diferenciação clara de nível:**
   - **AZ-900:** Foco conceitual, comparação de serviços (*Functions vs. App Service vs. VMs*, *Advisor vs. Monitor vs. Service Health*), custos (TCO/Pricing Calculator) e conformidade sem sintaxe profunda de CLI.
   - **AZ-104:** Foco operacional e de configuração exata (SKU *Basic vs. Standard* de Load Balancer/IP público, regras de NSG por prioridade, peering, Entra ID roles vs. Azure RBAC, backup/recovery vaults, quotas).
4. **No gabarito comentado:** Sempre relacione cada requisito do enunciado ao recurso exato e explique por que as alternativas incorretas falham por **custo desnecessário, quebra funcional (ex.: `ReadOnly` lock) ou SLA insuficiente**.
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Azure Identities & Governance -> 2) Azure Storage -> 3) Azure Compute Resources -> 4) Virtual Networking -> 5) Monitor & Backup), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
