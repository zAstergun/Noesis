# Cloud e Certificações AWS (Parâmetros para Geração de Simulados)

> **Banca / Provedor:** Amazon Web Services (AWS Training and Certification)  
> **Base Analisada:** *CLF-C02 Exam Guide*, *SAA-C03 Exam Guide*, *Cloud Practitioner Sample Questions*, *Solutions Architect Associate (SAA-C03) Sample Questions*, *Developer Associate (DVA-C02) Sample Questions*, *Machine Learning Specialty (MLS-C01) Sample Questions* (`d1.awsstatic.com`)  
> **Uso no Noesis:** Parâmetro para geração de simulados de certificações técnicas internacionais em Cloud, Arquitetura, Desenvolvimento, Segurança e ML.

---

## 1. Requisitos e Estrutura Oficial dos Exames AWS

| Certificação | Código | Questões (Pontuadas + Pré-teste) | Pontuação Mínima (Escala 100–1000) | Domínios e Pesos Oficiais |
| :--- | :---: | :---: | :---: | :--- |
| **Cloud Practitioner** | `CLF-C02` | **65** (50 pontuadas + 15 não pontuadas) | **700** | 1. Cloud Concepts (24%)<br>2. Security & Compliance (30%)<br>3. Cloud Technology & Services (34%)<br>4. Billing, Pricing & Support (12%) |
| **Solutions Architect – Associate** | `SAA-C03` | **65** (50 pontuadas + 15 não pontuadas) | **720** | 1. Design Secure Architectures (30%)<br>2. Design Resilient Architectures (26%)<br>3. Design High-Performing Architectures (24%)<br>4. Design Cost-Optimized Architectures (20%) |
| **Developer – Associate** | `DVA-C02` | **65** (50 pontuadas + 15 não pontuadas) | **720** | Development with AWS Services, Security, Deployment, Troubleshooting & Optimization |
| **Machine Learning – Specialty** | `MLS-C01` | **65** | **750** | Data Engineering, Exploratory Data Analysis, Modeling, ML Implementation & Operations |

### Formatos Oficiais das Questões
- **Multiple Choice:** 1 resposta correta + 3 distratores (`A`–`D`).
- **Multiple Response:** 2 ou mais respostas corretas entre 5 ou mais opções (`A`–`E`), sempre indicando explicitamente `(Select TWO.)` ou `(Select THREE.)`.
- **Modelo Compensatório:** não é preciso atingir nota mínima em cada domínio isolado; apenas a pontuação geral importa, e **não há penalidade por chute**.

---

## 2. Lógica de Elaboração e Arquitetura das Questões AWS

Os exames AWS (especialmente Associate e Specialty) possuem uma **arquitetura de cenário corporativo altamente padronizada**:

1. **Cenário Empresarial + Restrição Chave (Qualificador Decisivo):**
   - Toda questão *Associate/Specialty* começa descrevendo uma empresa (`A company runs...`, `A developer is building...`) com requisitos funcionais **e um qualificador restritivo** no final:
     - *"...with the LEAST operational overhead"* / *"...least amount of setup and maintenance"* (favorece serviços serverless/gerenciados: Glue/Lambda/Fargate/DynamoDB sobre EMR/EC2);
     - *"...as cost-effectively as possible"* + *"cannot be interrupted"* (elimina Spot Instances e favorece On-Demand/Savings Plans);
     - *"...in near real time"* / *"...without downtime"* / *"...decouple..."* (favorece SQS, AppSync, WebSocket API Gateway, Multi-AZ).
2. **Construção Cirúrgica dos Distratores:**
   - Segundo os Exam Guides oficiais, distratores são soluções **tecnicamente plausíveis para quem tem conhecimento incompleto**:
     - Serviços parecidos mas errados para o caso (ex.: *Systems Manager Parameter Store* vs. *Secrets Manager* quando há **rotação automática nativa de credenciais RDS**);
     - Configurações inválidas de rede/segurança (ex.: colocar NAT Gateway em *private subnet* em vez de *public subnet*, ou apontar rota de sub-rede privada diretamente para Internet Gateway);
     - Soluções que funcionam, mas violam o qualificador de **menor custo** ou **menor esforço operacional**.
3. **Diferença de Nível Cognitivo:**
   - **Practitioner (`CLF`):** perguntas diretas de identificação de serviço e modelo de responsabilidade compartilhada (*"Which AWS service..."*).
   - **Associate (`SAA` / `DVA`):** cenários multi-camada exigindo combinação de 2–3 serviços, políticas IAM/resource policies, CORS, envelope encryption, caching (*lazy loading* em pseudocódigo) e arquitetura Multi-AZ.

---

## 3. Exemplos Reais de Questões (Amostras Oficiais AWS)

### Exemplo 1 — Cloud Practitioner (`CLF`): Shared Responsibility Model (Q05)
**Question:** Which of the following is an AWS responsibility under the AWS shared responsibility model?  
- **A)** Configuring third-party applications
- **B)** Maintaining physical hardware
- **C)** Securing application access and data
- **D)** Managing guest operating systems

**Answer:** **B**  
**Lógica:** Separa responsabilidade *of the cloud* (AWS: hardware físico, instalações, rede física) vs. *in the cloud* (Cliente: guest OS em EC2, dados, aplicações, IAM).

---

### Exemplo 2 — Solutions Architect (`SAA-C03`): Rede Privada em VPC (`Select TWO`, Q01)
**Scenario:** A company runs a public-facing three-tier web application in a VPC across multiple Availability Zones. Amazon EC2 instances for the application tier running in private subnets need to download software patches from the internet. However, the EC2 instances cannot be directly accessible from the internet.  
Which actions should be taken to allow the EC2 instances to download the needed patches? **(Select TWO.)**  
- **A)** Configure a NAT gateway in a public subnet.
- **B)** Define a custom route table with a route to the NAT gateway for internet traffic and associate it with the private subnets for the application tier.
- **C)** Assign Elastic IP addresses to the EC2 instances.
- **D)** Define a custom route table with a route to the internet gateway for internet traffic and associate it with the private subnets for the application tier.
- **E)** Configure a NAT instance in a private subnet.

**Answers:** **A, B**  
**Lógica e Distratores:** C e D expõem as instâncias diretamente à internet (violando a restrição); E coloca o NAT dentro da *private subnet* (sem saída para o Internet Gateway). Padrão clássico de rede AWS.

---

### Exemplo 3 — Developer (`DVA-C02`): Caching / Lazy Loading em Pseudocódigo (Q07)
**Scenario:** A developer is adding Amazon ElastiCache for Memcached to a company's existing record storage application using lazy loading.  
Which pseudocode example will correctly implement lazy loading?  
- **A)** `record_value = db.query("UPDATE ..."); cache.set(...)`
- **B)**
```text
record_value = cache.get(record_key)
if (record_value == NULL)
  record_value = db.query("SELECT Details FROM Records WHERE ID == {0}", record_key)
  cache.set(record_key, record_value)
```
- **C)** `record_value = cache.get(...); db.query("UPDATE ...")`
- **D)** `record_value = db.query("SELECT ..."); if (record_value != NULL) cache.set(...)`

**Answer:** **B**  
**Lógica:** *Lazy loading* consulta o cache primeiro; apenas em *cache miss* (`NULL`) lê o banco e popula o cache. D lê o banco sempre (não economiza leitura); A e C escrevem no banco (*write-through* mal implementado).

---

### Exemplo 4 — Machine Learning Specialty (`MLS-C01`): Matriz de Confusão e Custo de Negócio (Q05)
**Scenario:** A false positive (FP) is $5\times$ more expensive than a false negative (FN). Criteria: 1) Recall $\ge 80\%$; 2) FPR $\le 10\%$; 3) Minimize business cost ($5\cdot\text{FP}+\text{FN}$).  
- **A)** TN=91, FP=9, FN=22, TP=78 → Recall = 0.78 (falha critério 1)
- **B)** TN=99, FP=1, FN=21, TP=79 → Recall = 0.79 (falha critério 1)
- **C)** TN=96, FP=4, FN=10, TP=90 → Recall = 0.90, FPR = 0.04, Custo = $5(4)+10 = 30$
- **D)** TN=98, FP=2, FN=18, TP=82 → Recall = 0.82, FPR = 0.02, Custo = $5(2)+18 = 28$

**Answer:** **D**  
**Lógica:** Exige calcular 3 métricas em todas as 4 opções e escolher a que satisfaz todas as restrições com menor custo.

---

## 4. Diretrizes Obrigatórias para a IA (Motor de Simulados Noesis)

1. **Incluir qualificadores decisivos claros** nos cenários (*"LEAST operational overhead"*, *"most cost-effectively"*, *"must not be interrupted"*, *"near real time"*).
2. **Alternar entre `Multiple Choice` (4 opções) e `Multiple Response` (5 opções com `(Select TWO.)`)**.
3. **Nunca criar distratores absurdos:** toda opção errada deve citar serviços reais do ecossistema da certificação (AWS/Azure/GCP/K8s/Security+) que falham por um detalhe arquitetural específico (permissão, rede, custo, escalabilidade ou persistência).
4. **Explicar cada opção no gabarito:** justificar tecnicamente por que a correta atende todos os requisitos e por que cada distrator falha no requisito restritivo.
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Design Secure Architectures -> 2) Design Resilient Architectures -> 3) Design High-Performing Architectures -> 4) Design Cost-Optimized Architectures), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
