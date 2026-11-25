# Kubernetes CNCF — CKA, CKAD & CKS (Linux Foundation / CNCF Curriculum)

> Guia de parâmetros para geração e correção de simulados pela IA — extraído diretamente do repositório oficial **`cncf/curriculum`** (`cncf_cka.pdf` / `CKAD` / `CKS`).

---

## 1. Requisitos e Estrutura Oficial (Provas Práticas Hands-On)

Diferente de certificações de múltipla escolha, **CKA, CKAD e CKS são exames 100% práticos em terminal Linux (`kubectl`, `helm`, `etcdctl`, `kubeadm`, `crictl`, `trivy`, `falco`)** contra clusters Kubernetes reais.

| Certificação | Foco | Duração | Questões (Tarefas Práticas) | Nota de Corte |
| :--- | :--- | :--- | :--- | :--- |
| **CKA** (*Certified Kubernetes Administrator*) | Administração, instalação, rede, armazenamento e troubleshooting de clusters | **2 horas** | 15–20 tarefas práticas (peso variável) | **66%** |
| **CKAD** (*Certified Kubernetes Application Developer*) | Design, build, deploy, observabilidade, configuração e rede de apps no K8s | **2 horas** | 15–20 tarefas práticas | **66%** |
| **CKS** (*Certified Kubernetes Security Specialist*) | Segurança de cluster, *hardening*, *supply chain* e runtime *(exige CKA ativo)* | **2 horas** | 15–20 tarefas práticas | **67%** |

*Nota:* As certificações teóricas de múltipla escolha da trilha CNCF são **KCNA** (Kubernetes and Cloud Native Associate) e **KCSA** (Security Associate) — 60 questões em 90 minutos, corte 75%.

### Pesos Oficiais dos Domínios (`cncf/curriculum`)
- **CKA:** Troubleshooting (**30%**) · Cluster Architecture, Installation & Configuration (**25%**) · Services & Networking (**20%**) · Workloads & Scheduling (**15%**) · Storage (**10%**).
- **CKAD** *(extraído diretamente do PDF oficial `CKAD Exam Curriculum`)*: Application Environment, Configuration and Security (**25%**) · Application Design and Build (**20%**) · Application Deployment (**20%**) · Services & Networking (**20%**) · Application Observability and Maintenance (**15%**).
- **CKS:** Minimize Microservice Vulnerabilities (**20%**) · Supply Chain Security (**20%**) · Monitoring, Logging and Runtime Security (**20%**) · Cluster Hardening (**15%**) · System Hardening (**15%**) · Cluster Setup (**10%**).

---

## 2. Lógica de Elaboração e Armadilhas Típicas do Exame

Como a correção dos exames CKA/CKAD/CKS é feita por scripts automatizados após o término da prova, cada tarefa exige **precisão exata de nomes, namespaces, labels, portas e contextos**:

1. **Troca de Contexto (`kubectl config use-context <ctx>`):** Todo enunciado começa instruindo o cluster/contexto alvo. Executar o manifesto no contexto anterior zera a questão instantaneamente.
2. **Nomes e Namespaces exatos:** Errar `namespace` (`default` em vez de `production`), porta (`targetPort` vs. `port`), ou selector label quebra o teste automatizado de conectividade/estado.
3. **Imutabilidade de campos em Pods/Deployments:** Tentar editar a imagem ou porta de um Pod estático/running exige recriar ou editar o controlador (`Deployment`) correto. Em provas com tempo apertado, comandos imperativos (`kubectl create ... --dry-run=client -o yaml > pod.yaml`) são essenciais para não perder tempo escrevendo YAML do zero.
4. **Troubleshooting real de Control Plane (CKA — 30%):**
   - Manifesto estático corrompido em `/etc/kubernetes/manifests/kube-apiserver.yaml` ou `kube-scheduler.yaml`;
   - `kubelet` parado no worker node (`systemctl status kubelet`, `/var/lib/kubelet/config.yaml`);
   - Backup e restore de `etcd` via `etcdctl snapshot save / restore` com `--endpoints`, `--cacert`, `--cert`, `--key`.
5. **NetworkPolicy & SecurityContext (CKAD/CKS):** Semântica padrão do K8s (*"allow all unless a NetworkPolicy selects the Pod"*), distinção entre regra `ingress` (múltiplos objetos `- from:` = **OR** vs. múltiplos seletores dentro do mesmo item `-` = **AND**), RBAC (`Role`/`ClusterRole` + `Binding`) e `AppArmor/Seccomp/PSP-PSA`.

---

## 3. Exemplos Reais e Cenários Práticos Comentados

### Exemplo 1 — CKA Troubleshooting / Control Plane (30% do exame)
> **Tarefa Prática (Cenário Real CKA):**  
> *"Set context to `k8s-prod`. A worker node named `worker-02` is showing status `NotReady`. Troubleshoot the node and ensure it returns to `Ready` state."*
>
> **Passo a passo de diagnóstico esperado:**  
> 1. `kubectl config use-context k8s-prod` e `kubectl get nodes` (confirmar `NotReady`).  
> 2. `ssh worker-02` -> verificar serviços: `sudo systemctl status kubelet containerd`.  
> 3. Se `kubelet` estiver inativo/falhando, inspecionar logs: `sudo journalctl -u kubelet -n 50 --no-pager`.  
> 4. Corrigir erro típico (ex.: caminho errado de certificado ou `--cgroup-driver` em `/var/lib/kubelet/config.yaml`, ou `systemctl enable --now kubelet`).  
> 5. Retornar ao node de controle e validar `kubectl get nodes` mostrando `Ready`.

### Exemplo 2 — CKAD Multi-Container Pod + Volumes + Probes (Padrão `cncf_ckad.pdf`)
> **Tarefa Prática (Cenário Real CKAD):**  
> *"In namespace `app-team`, create a Pod named `web-logger` with two containers:*  
> - *Container `nginx` using image `nginx:1.25`, mounting an `emptyDir` volume named `shared-logs` at `/var/log/nginx`, and exposing a `readinessProbe` via HTTP GET on `/` port `80` (`initialDelaySeconds: 5`).*  
> - *Container `sidecar` using image `busybox:1.36` running `sh -c 'tail -n+1 -f /logs/access.log'`, mounting the same volume at `/logs`."*
>
> **Pontos críticos avaliados:** Compartilhamento do mesmo `emptyDir` em *mountPaths* distintos, nomes exatos de namespace/pod/containers e configuração sintática correta de `readinessProbe`.

### Exemplo 3 — CKS Hardening / NetworkPolicy & RBAC (Padrão CKS)
> **Tarefa Prática:**  
> *"In namespace `payments`, create a `NetworkPolicy` named `deny-except-api` applied to Pods with `app=db`, allowing TCP ingress on port `5432` ONLY from Pods in namespace `backend` labeled `role=api`."*  
> **Armadilha clássica:** Colocar `namespaceSelector` e `podSelector` em dois elementos separados com hífen (`- namespaceSelector:` e `- podSelector:`), o que cria regra **OR** em vez de **AND** — abrindo o banco para *todos* os pods do namespace `backend`!

---

## 4. Diretrizes Obrigatórias para a IA (Geração de Simulados)

1. **Adapte o formato ao exame solicitado pelo usuário:**
   - **Se CKA / CKAD / CKS:** Gere **Desafios Práticos de Laboratório (`Hands-On Lab Tasks`)** contendo **Contexto/Namespace explícito, Requisitos exatos, Restrições de segurança/recursos e Gabarito com comandos `kubectl`/YAML completo e comandos de verificação (`kubectl get/describe/logs`)**.
   - **Se KCNA / KCSA** (ou se o usuário pedir treino rápido teórico de K8s): Gere questões objetivas de 4 alternativas baseadas em cenários de arquitetura, `kubectl` e conceitos CNCF.
2. **Respeite rigorosamente os pesos oficiais de `cncf/curriculum`:** Priorize *Troubleshooting* (30%) no CKA, *Configuration/Security/Design/Deploy/Networking* (20–25% cada) no CKAD, e *Supply Chain / Runtime / Microservice Hardening* no CKS.
3. **YAML válido e sintaxe moderna (Kubernetes 1.30+):** Evite APIs depreciadas (ex.: use `networking.k8s.io/v1` para `Ingress` e `NetworkPolicy`, `policy/v1` para `PodDisruptionBudget`, e *Pod Security Admission* em vez do obsoleto `PodSecurityPolicy`).
4. **Destaque as armadilhas de correção automatizada:** Sempre lembre no gabarito campos sensíveis como `OR vs. AND` em *NetworkPolicy*, `emptyDir` vs. `PVC`, e uso de `--dry-run=client -o yaml`.
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Cluster Architecture & Workloads -> 2) Services, Ingress & NetworkPolicies -> 3) Storage & Configuration -> 4) Troubleshooting & Observability), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
