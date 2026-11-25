# CompTIA Security+ (SY0-701) & Segurança Aplicada (OWASP Top 10)

> Guia de parâmetros para geração e correção de simulados pela IA — alinhado aos **Objetivos Oficiais do Exame CompTIA Security+ SY0-701** (`comptia.org`) e ao padrão **OWASP Top 10**.

---

## 1. Requisitos e Estrutura Oficial

| Parâmetro | CompTIA Security+ (SY0-701) |
| :--- | :--- |
| **Questões e Formato** | Máximo **90 questões** · Múltipla escolha (única ou múltipla seleção) + **PBQs** (*Performance-Based Questions* / cenários práticos simulados no início da prova) |
| **Duração** | **90 minutos** |
| **Pontuação e Corte** | Escala **100 – 900** · Nota mínima de aprovação: **750 / 900** |
| **Idiomas** | Inglês, Japonês, Português (em ciclos específicos), Espanhol |

### Domínios Oficiais e Pesos (SY0-701)
1. **1.0 General Security Concepts** — **12%** (Controles de segurança, CIA Triad, Zero Trust, criptografia, PKI)
2. **2.0 Threats, Vulnerabilities, and Mitigations** — **22%** (Atores de ameaça, engenharia social, malware, OWASP/injeções, *hardening*)
3. **3.0 Security Architecture** — **18%** (Cloud, microssegmentação, IAM, *resilience*, *availability*, backup 3-2-1)
4. **4.0 Security Operations** — **28%** *(Maior peso)* (SIEM, SOC, resposta a incidentes PICERL, forense, análise de logs, EDR/XDR)
5. **5.0 Security Program Management and Oversight** — **20%** (GRC, políticas, gestão de riscos, terceiros/TPRM, auditorias, LGPD/GDPR)

---

## 2. Lógica de Elaboração e Arquitetura dos Distratores

A CompTIA testa aplicação situacional com forte uso de modificadores restritivos no comando (**"MOST likely"**, **"BEST"**, **"FIRST"**, **"LEAST"**):

1. **Hierarquia "FIRST / BEST / MOST cost-effective":** Vários distratores são tecnicamente válidos em algum momento da resposta a incidentes, mas violam a **ordem do ciclo de vida** (ex.: erradicar/apagar logs antes de conter/isolar e coletar evidência volátil; ou implantar WAF caro quando validação de entrada parametrizada é pedida como solução raiz).
2. **Classificação de Controles (1.1):** Exige distinguir rigorosamente **Tipo** (*Technical, Managerial, Operational, Physical*) × **Função** (*Preventive, Detective, Corrective, Deterrent, Compensating, Directive*). Distratores misturam *Detective* (SIEM/IDS, câmeras, auditoria de log) com *Preventive* (Firewall, IPS, MFA) ou *Compensating* (controle alternativo temporário para sistema legado sem patch).
3. **Leitura de Logs e Ferramentas CLI (4.0):** Questões trazem saídas reais de `nmap`, `tcpdump`, cabeçalhos HTTP, logs do Apache/Syslog ou alertas de SIEM para identificar SQLi (`' OR 1=1 --`), XSS (`<script>`), CSRF, SSRF ou *Path Traversal* (`../../etc/passwd`).
4. **Criptografia e PKI:** Distratores exploram confusão entre **Confidencialidade** (criptografar com chave **pública do destinatário** ou chave simétrica) vs. **Integridade/Autenticidade/Não-repúdio** (assinar com chave **privada do remetente** + hash SHA-256).

---

## 3. Exemplos Reais e Modelos Comentados (`comptia.org` & PBQ)

### Exemplo 1 — Classificação de Controles (Estilo Oficial SY0-701)
> **Question:** A systems administrator wants to deploy a security control that decreases the likelihood of a cyberattack or unauthorized access attempt occurring on a corporate network segment.  
> **Which of the following types of controls is the administrator implementing?**  
> **A.** Corrective  
> **B.** Detective  
> **C.** Preventive  
> **D.** Compensating  
>
> **Gabarito:** **C (Preventive)**  
> **Comentário:** Controles **Preventivos** reduzem a probabilidade ou bloqueiam o ataque *antes* de ocorrer (ACL, firewall, MFA). **Detective (B)** apenas identifica/alerta durante ou após (IDS, logs); **Corrective (A)** restaura após incidente (restore de backup, patch pós-ataque); **Compensating (D)** substitui um controle primário inviável.

### Exemplo 2 — Security Operations & OWASP Top 10 (Cenário Prático)
> **Scenario:** Um analista de SOC observa nos logs do servidor web múltiplas requisições `GET /download?file=../../../../etc/shadow` retornando HTTP 200, seguidas por tentativas de login SSH com usuários listados no arquivo.  
> **Which of the following attacks occurred FIRST, and what is the BEST long-term remediation?**  
> **A.** Broken Access Control / Path Traversal; implement strict input allow-listing and chroot/canonical path validation.  
> **B.** Cross-Site Scripting (XSS); enable HttpOnly cookies and Content Security Policy (CSP).  
> **C.** SQL Injection; migrate queries to prepared statements with parameterized bindings.  
> **D.** Server-Side Request Forgery (SSRF); block outbound metadata IP `169.254.169.254` at the firewall.  
>
> **Gabarito:** **A**  
> **Comentário:** O padrão `../../../../` evidencia **Directory/Path Traversal** (enquadrado em *Broken Access Control* no OWASP Top 10). As opções B, C e D citam remediações corretas para *outras* classes de vulnerabilidade web.

### Exemplo 3 — PBQ (Performance-Based Question) Típico
> **Formato simulado em texto:** Configurar regras ordenadas de **Firewall / ACL** (lembrando avaliação *top-down* até o `Implicit Deny All` no final) ou parear **6 logs de ataque** (Phishing, Ransomware, DNS Poisoning, ARP Spoofing, Brute Force, XSS) ao **indicador de comprometimento** e à **contenção imediata**.

---

## 4. Diretrizes Obrigatórias para a IA (Geração de Simulados)

1. **Respeite o peso dos 5 domínios SY0-701:** Dê maior volume de questões a **Security Operations (28%)** e **Threats/Vulnerabilities/Mitigations (22%)**, integrando cenários de nuvem, SOC e OWASP Top 10.
2. **Use comandos decisórios CompTIA:** Destaque em MAIÚSCULAS termos como **`MOST likely`**, **`BEST`**, **`FIRST`** ou **`NEXT`**, e construa cenários onde todas as alternativas pareçam razoáveis à primeira vista, mas apenas uma respeite o **requisito de negócio/ordem de IR (PICERL)** ou **menor privilégio / menor custo**.
3. **Inclua ao menos 1 PBQ por bloco de simulado:** Simule cenários de configuração de regra de firewall/ACL, análise de saída `nmap` ou classificação em tabela (*Tipo de Ataque -> Indicador -> Remediação*).
4. **No gabarito comentado:** Explique tanto os conceitos técnicos quanto a **regra de priorização do exame** (por que fazer X *antes* de Y, e por que cada distrator pertence a outra fase ou domínio).
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) 1.0 General Security Concepts -> 2) 2.0 Threats, Vulnerabilities & Mitigations -> 3) 3.0 Security Architecture -> 4) 4.0 Security Operations -> 5) 5.0 Security Program Management), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
