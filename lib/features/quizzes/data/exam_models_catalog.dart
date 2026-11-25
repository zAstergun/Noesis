import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../../core/constants.dart';

/// Categorias principais dos modelos oficiais de prova em `exemplos_simulados/`.
enum ExamCategory {
  all('Todos', Icons.apps_rounded, AsterConstants.lavanda),
  vestibulares('Vestibulares BR', Icons.school_outlined, AsterConstants.lavanda),
  internacionais('Internacionais', Icons.public_rounded, AsterConstants.ambar),
  idiomas('Idiomas', Icons.translate_rounded, AsterConstants.menta),
  tecnologia('Tech & Cloud', Icons.memory_rounded, AsterConstants.lavanda),
  juridico('Jurídico & Concursos', Icons.gavel_rounded, AsterConstants.coral),
  saude('Saúde & Medicina', Icons.medical_services_outlined, AsterConstants.menta),
  financas('Finanças & Econ.', Icons.trending_up_rounded, AsterConstants.ambar);

  const ExamCategory(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

/// Representa uma parte/disciplina sequencial dentro de uma prova oficial.
class ExamSectionSlice {
  const ExamSectionSlice({
    required this.name,
    required this.weight,
  });

  final String name;
  final double weight;
}

/// Representa um modelo oficial de prova/banca com parâmetros em `.md`.
class ExamModelTemplate {
  const ExamModelTemplate({
    required this.id,
    required this.name,
    required this.badge,
    required this.category,
    required this.subject,
    required this.topic,
    required this.summary,
    required this.recommendedCount,
    required this.optionsFormat,
    required this.difficulty,
    required this.assetPath,
    required this.icon,
    required this.accent,
    required this.sections,
  });

  final String id;
  final String name;
  final String badge;
  final ExamCategory category;
  final String subject;
  final String topic;
  final String summary;
  final int recommendedCount;
  final String optionsFormat;
  final String difficulty;
  final String assetPath;
  final IconData icon;
  final Color accent;

  /// Partes/disciplinas na ordem oficial do caderno de prova (sem misturar áreas).
  final List<ExamSectionSlice> sections;

  /// Mapeia cada questão `1..totalTarget` à sua disciplina sequencial exata.
  List<String> resolveSectionPerQuestion(int totalTarget) {
    if (totalTarget <= 0) return const [];
    if (sections.isEmpty) {
      return List<String>.filled(totalTarget, subject);
    }

    final sumWeight = sections.fold<double>(0, (acc, s) => acc + s.weight);
    final safeSum = sumWeight > 0 ? sumWeight : sections.length.toDouble();

    // Distribuição proporcional via maior resto (Hamilton) para somar exatamente totalTarget
    final rawCounts = sections
        .map((s) => (s.weight / safeSum) * totalTarget)
        .toList();
    final counts = rawCounts.map((v) => v.floor()).toList();
    int assigned = counts.fold<int>(0, (a, b) => a + b);

    final remainders = List<int>.generate(sections.length, (i) => i)
      ..sort((a, b) => (rawCounts[b] - counts[b]).compareTo(rawCounts[a] - counts[a]));
    int cursor = 0;
    while (assigned < totalTarget && remainders.isNotEmpty) {
      final idx = remainders[cursor % remainders.length];
      counts[idx]++;
      assigned++;
      cursor++;
    }

    final result = <String>[];
    for (int i = 0; i < sections.length; i++) {
      for (int c = 0; c < counts[i]; c++) {
        result.add(sections[i].name);
      }
    }
    return result;
  }

  /// Gera a lista de disciplinas exatas para o lote [startNumber .. startNumber + batchCount - 1].
  List<String> disciplinesForBatch({
    required int totalTarget,
    required int startNumber,
    required int batchCount,
  }) {
    final fullPlan = resolveSectionPerQuestion(totalTarget);
    if (fullPlan.isEmpty) return List<String>.filled(batchCount, subject);

    return List<String>.generate(batchCount, (offset) {
      final idx = (startNumber - 1 + offset).clamp(0, fullPlan.length - 1);
      return fullPlan[idx];
    });
  }

  /// Texto compacto com a divisão sequencial exata das questões deste lote para o prompt da IA.
  String formatBatchSectionDirective({
    required int totalTarget,
    required int startNumber,
    required int batchCount,
  }) {
    final batchDisciplines = disciplinesForBatch(
      totalTarget: totalTarget,
      startNumber: startNumber,
      batchCount: batchCount,
    );
    if (batchDisciplines.isEmpty) return '';

    final runs = <({String name, int from, int to})>[];
    String current = batchDisciplines.first;
    int runStart = startNumber;

    for (int i = 1; i < batchDisciplines.length; i++) {
      if (batchDisciplines[i] != current) {
        runs.add((name: current, from: runStart, to: startNumber + i - 1));
        current = batchDisciplines[i];
        runStart = startNumber + i;
      }
    }
    runs.add((name: current, from: runStart, to: startNumber + batchDisciplines.length - 1));

    final breakdown = runs
        .map((r) => r.from == r.to
            ? '- Questão ${r.from}: obrigatoriamente da disciplina "${r.name}"'
            : '- Questões ${r.from} a ${r.to} (${r.to - r.from + 1} questões seguidas): obrigatoriamente da disciplina "${r.name}"')
        .join('\n');

    return '''
ORDEM SEQUENCIAL OBRIGATÓRIA DESTE LOTE (NÃO MISTURE DISCIPLINAS FORA DOS BLOCOS):
$breakdown
Preencha o campo "discipline" de cada questão exatamente com o nome da disciplina correspondente ao bloco acima (ou subárea específica, ex.: "Ciências da Natureza · Física").
''';
  }
}

/// Catálogo completo dos 38 modelos oficiais de simulados disponíveis no Noesis.
class ExamModelsCatalog {
  ExamModelsCatalog._();

  static final Map<String, String> _blueprintCache = {};

  static ExamModelTemplate? findByName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final clean = name.trim().toLowerCase();
    for (final m in models) {
      if (m.name.toLowerCase() == clean || m.id.toLowerCase() == clean) {
        return m;
      }
    }
    return null;
  }

  static const List<ExamModelTemplate> models = [
    // ── Tecnologia & Cloud ──────────────────────────────────────────────────
    ExamModelTemplate(
      id: 'comptia_security_plus',
      name: 'CompTIA Security+',
      badge: 'SY0-701',
      category: ExamCategory.tecnologia,
      subject: 'Cybersegurança',
      topic: 'CompTIA Security+ SY0-701 & OWASP Top 10',
      summary: 'Controles, operações SOC, vulnerabilidades, PBQs e priorização FIRST/BEST.',
      recommendedCount: 90,
      optionsFormat: '4 opções (A–D)',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/tecnologia_e_certificacoes/comptia_security_plus/comptia_security_plus.md',
      icon: Icons.shield_outlined,
      accent: AsterConstants.lavanda,
      sections: [
        ExamSectionSlice(name: '1.0 General Security Concepts', weight: 12),
        ExamSectionSlice(name: '2.0 Threats, Vulnerabilities & Mitigations', weight: 22),
        ExamSectionSlice(name: '3.0 Security Architecture', weight: 18),
        ExamSectionSlice(name: '4.0 Security Operations', weight: 28),
        ExamSectionSlice(name: '5.0 Security Program Management', weight: 20),
      ],
    ),
    ExamModelTemplate(
      id: 'cloud_e_certificacoes',
      name: 'AWS Solutions Architect',
      badge: 'SAA-C03',
      category: ExamCategory.tecnologia,
      subject: 'Cloud Computing',
      topic: 'AWS Solutions Architect Associate (SAA-C03)',
      summary: 'Arquitetura resiliente, custos, segurança IAM/KMS, VPC e alta disponibilidade.',
      recommendedCount: 65,
      optionsFormat: '4 opções (A–D)',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/tecnologia_e_certificacoes/cloud_e_certificacoes/cloud_e_certificacoes.md',
      icon: Icons.cloud_outlined,
      accent: AsterConstants.ambar,
      sections: [
        ExamSectionSlice(name: 'Design Secure Architectures', weight: 30),
        ExamSectionSlice(name: 'Design Resilient Architectures', weight: 26),
        ExamSectionSlice(name: 'Design High-Performing Architectures', weight: 24),
        ExamSectionSlice(name: 'Design Cost-Optimized Architectures', weight: 20),
      ],
    ),
    ExamModelTemplate(
      id: 'owasp_appsec',
      name: 'OWASP Top 10 & AppSec',
      badge: 'AppSec',
      category: ExamCategory.tecnologia,
      subject: 'Segurança de Software',
      topic: 'OWASP Top 10 · Vulnerabilidades Web e Mitigações',
      summary: 'A01–A10, SSRF, XSS, SQLi, Broken Access Control e hardening de APIs.',
      recommendedCount: 25,
      optionsFormat: '4 opções (A–D)',
      difficulty: 'Médio / Prático',
      assetPath: 'exemplos_simulados/tecnologia_e_certificacoes/comptia_security_plus/comptia_security_plus.md',
      icon: Icons.lock_outline_rounded,
      accent: AsterConstants.coral,
      sections: [
        ExamSectionSlice(name: 'Access Control & Authentication (A01/A07)', weight: 35),
        ExamSectionSlice(name: 'Injection, XSS & SSRF (A03/A10)', weight: 35),
        ExamSectionSlice(name: 'Crypto, Config & Supply Chain', weight: 30),
      ],
    ),
    ExamModelTemplate(
      id: 'kubernetes_cncf',
      name: 'Kubernetes CNCF',
      badge: 'CKA / CKAD',
      category: ExamCategory.tecnologia,
      subject: 'Infraestrutura & DevOps',
      topic: 'Kubernetes CKA, CKAD & CKS (Troubleshooting, RBAC, NetworkPolicy)',
      summary: 'Cenários práticos com kubectl/YAML, control plane, pods, storage e hardening.',
      recommendedCount: 18,
      optionsFormat: 'Cenários & 4 opções',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/tecnologia_e_certificacoes/kubernetes_cncf/kubernetes_cncf.md',
      icon: Icons.hub_outlined,
      accent: AsterConstants.lavanda,
      sections: [
        ExamSectionSlice(name: 'Cluster Architecture & Workloads', weight: 40),
        ExamSectionSlice(name: 'Services, Ingress & NetworkPolicies', weight: 20),
        ExamSectionSlice(name: 'Storage & Configuration', weight: 10),
        ExamSectionSlice(name: 'Troubleshooting & Observability', weight: 30),
      ],
    ),
    ExamModelTemplate(
      id: 'microsoft_azure',
      name: 'Microsoft Azure',
      badge: 'AZ-900/104',
      category: ExamCategory.tecnologia,
      subject: 'Cloud Computing · Azure',
      topic: 'Microsoft Azure Administrator (AZ-104) & Fundamentals (AZ-900)',
      summary: 'Entra ID, RBAC, Resource Locks, VNets/NSG, Storage e estudos de caso.',
      recommendedCount: 50,
      optionsFormat: '4–5 opções / Yes-No',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/tecnologia_e_certificacoes/microsoft_azure/microsoft_azure.md',
      icon: Icons.dns_outlined,
      accent: AsterConstants.ambar,
      sections: [
        ExamSectionSlice(name: 'Azure Identities & Governance', weight: 25),
        ExamSectionSlice(name: 'Azure Storage', weight: 15),
        ExamSectionSlice(name: 'Azure Compute Resources', weight: 25),
        ExamSectionSlice(name: 'Virtual Networking', weight: 20),
        ExamSectionSlice(name: 'Monitor & Backup', weight: 15),
      ],
    ),
    ExamModelTemplate(
      id: 'google_cloud',
      name: 'Google Cloud (GCP)',
      badge: 'ACE / PCA',
      category: ExamCategory.tecnologia,
      subject: 'Cloud Computing · GCP',
      topic: 'Google Cloud Associate Cloud Engineer & Cloud Architect',
      summary: 'IAM, Service Accounts, Cloud Run, GKE, BigQuery, Bigtable e gcloud CLI.',
      recommendedCount: 50,
      optionsFormat: '4 opções (A–D)',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/tecnologia_e_certificacoes/google_cloud/google_cloud.md',
      icon: Icons.cloud_queue_rounded,
      accent: AsterConstants.menta,
      sections: [
        ExamSectionSlice(name: 'Cloud Setup & Billing', weight: 20),
        ExamSectionSlice(name: 'Planning & Architecture', weight: 18),
        ExamSectionSlice(name: 'Deploying Solutions (GKE/Run/VMs)', weight: 25),
        ExamSectionSlice(name: 'Operations & Monitoring', weight: 20),
        ExamSectionSlice(name: 'IAM & Security', weight: 17),
      ],
    ),
    ExamModelTemplate(
      id: 'cisco_ccna',
      name: 'Cisco CCNA',
      badge: '200-301',
      category: ExamCategory.tecnologia,
      subject: 'Redes de Computadores',
      topic: 'Cisco CCNA 200-301 v1.1 (Switching, OSPF, Routing, CLI IOS, APIs)',
      summary: 'Subnetting VLSM, Longest Prefix Match, VLANs, STP, ACLs e saídas CLI IOS.',
      recommendedCount: 100,
      optionsFormat: '4 opções + CLI',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/tecnologia_e_certificacoes/cisco_ccna/cisco_ccna.md',
      icon: Icons.router_outlined,
      accent: AsterConstants.coral,
      sections: [
        ExamSectionSlice(name: 'Network Fundamentals', weight: 20),
        ExamSectionSlice(name: 'Network Access (VLAN/STP)', weight: 20),
        ExamSectionSlice(name: 'IP Connectivity (Routing/OSPF)', weight: 25),
        ExamSectionSlice(name: 'IP Services', weight: 10),
        ExamSectionSlice(name: 'Security Fundamentals', weight: 15),
        ExamSectionSlice(name: 'Automation & Programmability', weight: 10),
      ],
    ),
    ExamModelTemplate(
      id: 'poscomp',
      name: 'POSCOMP (SBC)',
      badge: 'Pós-Grad CS',
      category: ExamCategory.tecnologia,
      subject: 'Ciência da Computação',
      topic: 'POSCOMP · Matemática, Fundamentos da Computação e Tecnologia',
      summary: 'Teoria da computação, grafos, SO, arquitetura, compiladores e matemática discreta.',
      recommendedCount: 70,
      optionsFormat: '5 opções (A–E)',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/tecnologia_e_certificacoes/poscomp/poscomp.md',
      icon: Icons.functions_rounded,
      accent: AsterConstants.lavanda,
      sections: [
        ExamSectionSlice(name: 'Matemática da Computação', weight: 29),
        ExamSectionSlice(name: 'Fundamentos da Computação', weight: 43),
        ExamSectionSlice(name: 'Tecnologia da Computação', weight: 28),
      ],
    ),
    ExamModelTemplate(
      id: 'enade_computacao',
      name: 'ENADE Computação',
      badge: 'INEP · CC/ES',
      category: ExamCategory.tecnologia,
      subject: 'Computação & Engenharia',
      topic: 'ENADE Computação (Formação Geral + Específica, Asserção-Razão)',
      summary: 'Engenharia de software, bancos de dados, algoritmos e itens de asserção-razão.',
      recommendedCount: 40,
      optionsFormat: '5 opções (A–E)',
      difficulty: 'Médio / Prático',
      assetPath: 'exemplos_simulados/tecnologia_e_certificacoes/enade_computacao/enade_computacao.md',
      icon: Icons.code_rounded,
      accent: AsterConstants.menta,
      sections: [
        ExamSectionSlice(name: 'Formação Geral', weight: 25),
        ExamSectionSlice(name: 'Componente Específico · Computação', weight: 75),
      ],
    ),
    ExamModelTemplate(
      id: 'obi',
      name: 'OBI (UNICAMP / SBC)',
      badge: 'Olimpíada',
      category: ExamCategory.tecnologia,
      subject: 'Algoritmos & Lógica',
      topic: 'Olimpíada Brasileira de Informática (Iniciação e Programação)',
      summary: 'Enigmas dedutivos (Iniciação) e problemas algorítmicos com subtarefas e complexidade.',
      recommendedCount: 15,
      optionsFormat: '5 opções / Problemas',
      difficulty: 'Médio / Prático',
      assetPath: 'exemplos_simulados/tecnologia_e_certificacoes/obi/obi.md',
      icon: Icons.terminal_rounded,
      accent: AsterConstants.ambar,
      sections: [
        ExamSectionSlice(name: 'Raciocínio Lógico (Iniciação)', weight: 40),
        ExamSectionSlice(name: 'Algoritmos & Estruturas de Dados', weight: 60),
      ],
    ),

    // ── Vestibulares Brasil ─────────────────────────────────────────────────
    ExamModelTemplate(
      id: 'enem',
      name: 'ENEM (INEP)',
      badge: '90 Q / Dia · TRI',
      category: ExamCategory.vestibulares,
      subject: 'Ensino Médio · ENEM',
      topic: 'ENEM · Linguagens, Humanas, Natureza e Matemática (Matriz INEP)',
      summary: 'Caderno dividido sequencialmente por área do conhecimento (sem misturar), padrão TRI.',
      recommendedCount: 90,
      optionsFormat: '5 opções (A–E)',
      difficulty: 'Médio / Prático',
      assetPath: 'exemplos_simulados/vestibulares_brasil/enem/enem.md',
      icon: Icons.menu_book_rounded,
      accent: AsterConstants.lavanda,
      sections: [
        ExamSectionSlice(name: 'Linguagens, Códigos e suas Tecnologias', weight: 25),
        ExamSectionSlice(name: 'Ciências Humanas e suas Tecnologias', weight: 25),
        ExamSectionSlice(name: 'Ciências da Natureza e suas Tecnologias', weight: 25),
        ExamSectionSlice(name: 'Matemática e suas Tecnologias', weight: 25),
      ],
    ),
    ExamModelTemplate(
      id: 'fuvest',
      name: 'FUVEST / USP',
      badge: '1ª Fase · 90 Q',
      category: ExamCategory.vestibulares,
      subject: 'Vestibular · FUVEST',
      topic: 'FUVEST USP · Analítica Interdisciplinar e Obras Literárias',
      summary: 'Alta densidade conceitual, gráficos científicos, literatura e blocos por área.',
      recommendedCount: 90,
      optionsFormat: '5 opções (A–E)',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/vestibulares_brasil/fuvest/fuvest.md',
      icon: Icons.account_balance_outlined,
      accent: AsterConstants.coral,
      sections: [
        ExamSectionSlice(name: 'Língua Portuguesa, Literatura & Inglês', weight: 28),
        ExamSectionSlice(name: 'História & Geografia', weight: 24),
        ExamSectionSlice(name: 'Biologia & Química', weight: 24),
        ExamSectionSlice(name: 'Física & Matemática', weight: 24),
      ],
    ),
    ExamModelTemplate(
      id: 'unicamp',
      name: 'UNICAMP (Comvest)',
      badge: '1ª Fase · 72 Q',
      category: ExamCategory.vestibulares,
      subject: 'Vestibular · UNICAMP',
      topic: 'UNICAMP Comvest · Interpretação Crítica e Exatas Contextualizadas',
      summary: '4 alternativas objetivas, charges/dados atuais e blocos disciplinares sequenciais.',
      recommendedCount: 72,
      optionsFormat: '4 opções (A–D)',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/vestibulares_brasil/unicamp/unicamp.md',
      icon: Icons.science_outlined,
      accent: AsterConstants.ambar,
      sections: [
        ExamSectionSlice(name: 'Língua Portuguesa, Literatura & Inglês', weight: 28),
        ExamSectionSlice(name: 'Ciências Humanas (História/Geografia/Filosofia)', weight: 24),
        ExamSectionSlice(name: 'Ciências da Natureza (Biologia/Física/Química)', weight: 30),
        ExamSectionSlice(name: 'Matemática', weight: 18),
      ],
    ),
    ExamModelTemplate(
      id: 'unesp',
      name: 'UNESP (Vunesp)',
      badge: '1ª Fase · 90 Q',
      category: ExamCategory.vestibulares,
      subject: 'Vestibular · UNESP',
      topic: 'UNESP Vunesp · Conteúdo Programático e Leitura Contextualizada',
      summary: 'Divisão oficial em 3 blocos de 30 questões: Linguagens, Humanas e Natureza/Mat.',
      recommendedCount: 90,
      optionsFormat: '5 opções (A–E)',
      difficulty: 'Médio / Prático',
      assetPath: 'exemplos_simulados/vestibulares_brasil/unesp/unesp.md',
      icon: Icons.biotech_outlined,
      accent: AsterConstants.menta,
      sections: [
        ExamSectionSlice(name: 'Linguagens e Códigos', weight: 33.3),
        ExamSectionSlice(name: 'Ciências Humanas', weight: 33.3),
        ExamSectionSlice(name: 'Ciências da Natureza e Matemática', weight: 33.4),
      ],
    ),
    ExamModelTemplate(
      id: 'ita',
      name: 'ITA (Vestibular)',
      badge: '1ª Fase · 48 Q',
      category: ExamCategory.vestibulares,
      subject: 'Exatas · ITA',
      topic: 'ITA · Matemática, Física, Química e Linguagens de Altíssima Exigência',
      summary: 'Caderno dividido em blocos iguais: Matemática, Física, Química e Inglês.',
      recommendedCount: 48,
      optionsFormat: '5 opções (A–E)',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/vestibulares_brasil/ita/ita.md',
      icon: Icons.rocket_launch_outlined,
      accent: AsterConstants.coral,
      sections: [
        ExamSectionSlice(name: 'Matemática', weight: 25),
        ExamSectionSlice(name: 'Física', weight: 25),
        ExamSectionSlice(name: 'Química', weight: 25),
        ExamSectionSlice(name: 'Inglês & Português', weight: 25),
      ],
    ),
    ExamModelTemplate(
      id: 'encceja',
      name: 'ENCCEJA (INEP)',
      badge: '120 Q · EM',
      category: ExamCategory.vestibulares,
      subject: 'Educação Básica',
      topic: 'ENCCEJA Ensino Médio / Fundamental (Situações Cotidianas e Cidadania)',
      summary: '4 blocos sequenciais de 30 questões: Natureza, Matemática, Linguagens e Humanas.',
      recommendedCount: 120,
      optionsFormat: '4 opções (A–D)',
      difficulty: 'Iniciante / Fundamentos',
      assetPath: 'exemplos_simulados/vestibulares_brasil/encceja/encceja.md',
      icon: Icons.workspace_premium_outlined,
      accent: AsterConstants.menta,
      sections: [
        ExamSectionSlice(name: 'Ciências da Natureza e suas Tecnologias', weight: 25),
        ExamSectionSlice(name: 'Matemática e suas Tecnologias', weight: 25),
        ExamSectionSlice(name: 'Linguagens, Códigos e suas Tecnologias', weight: 25),
        ExamSectionSlice(name: 'Ciências Humanas e suas Tecnologias', weight: 25),
      ],
    ),

    // ── Internacionais ──────────────────────────────────────────────────────
    ExamModelTemplate(
      id: 'sat',
      name: 'Digital SAT',
      badge: '98 Q · 400–1600',
      category: ExamCategory.internacionais,
      subject: 'SAT · College Board',
      topic: 'Digital SAT · Reading & Writing (Craft/Structure/Expression) + Math',
      summary: 'Bloco 1 de Reading & Writing seguido pelo bloco 2 de Math em inglês.',
      recommendedCount: 98,
      optionsFormat: '4 opções (A–D)',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/internacionais/sat/sat.md',
      icon: Icons.public_rounded,
      accent: AsterConstants.lavanda,
      sections: [
        ExamSectionSlice(name: 'Reading and Writing', weight: 55),
        ExamSectionSlice(name: 'Math', weight: 45),
      ],
    ),
    ExamModelTemplate(
      id: 'act',
      name: 'Enhanced ACT',
      badge: '1–36 · 4 Alt',
      category: ExamCategory.internacionais,
      subject: 'ACT · Admissions',
      topic: 'Enhanced ACT · English (NO CHANGE), Math, Reading & Science',
      summary: 'Seções sequenciais: English, Mathematics, Reading e Science.',
      recommendedCount: 131,
      optionsFormat: '4 opções (A–D)',
      difficulty: 'Médio / Prático',
      assetPath: 'exemplos_simulados/internacionais/act/act.md',
      icon: Icons.timer_outlined,
      accent: AsterConstants.ambar,
      sections: [
        ExamSectionSlice(name: 'ACT English', weight: 38),
        ExamSectionSlice(name: 'ACT Mathematics', weight: 34),
        ExamSectionSlice(name: 'ACT Reading', weight: 28),
      ],
    ),
    ExamModelTemplate(
      id: 'gre',
      name: 'GRE General Test',
      badge: '54 Q · 130–170',
      category: ExamCategory.internacionais,
      subject: 'GRE · ETS',
      topic: 'GRE · Quantitative Comparison, Text Completion & Sentence Equivalence',
      summary: 'Seção Verbal Reasoning seguida pela seção Quantitative Reasoning em inglês.',
      recommendedCount: 54,
      optionsFormat: 'QC / TC / SE (4–6)',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/internacionais/gre/gre.md',
      icon: Icons.psychology_alt_outlined,
      accent: AsterConstants.lavanda,
      sections: [
        ExamSectionSlice(name: 'Verbal Reasoning (TC / SE / RC)', weight: 50),
        ExamSectionSlice(name: 'Quantitative Reasoning (QC & Problem Solving)', weight: 50),
      ],
    ),
    ExamModelTemplate(
      id: 'gmat',
      name: 'GMAT Focus Edition',
      badge: '64 Q · 205–805',
      category: ExamCategory.internacionais,
      subject: 'GMAT · Business',
      topic: 'GMAT Focus · Data Sufficiency, Critical Reasoning & Problem Solving',
      summary: 'Seções sequenciais: Quantitative, Verbal Reasoning e Data Insights.',
      recommendedCount: 64,
      optionsFormat: '5 opções (A–E)',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/internacionais/gmat/gmat.md',
      icon: Icons.analytics_outlined,
      accent: AsterConstants.coral,
      sections: [
        ExamSectionSlice(name: 'Quantitative Reasoning', weight: 33),
        ExamSectionSlice(name: 'Verbal Reasoning (CR & RC)', weight: 36),
        ExamSectionSlice(name: 'Data Insights (Data Sufficiency & Analysis)', weight: 31),
      ],
    ),
    ExamModelTemplate(
      id: 'lsat',
      name: 'LSAT (LSAC)',
      badge: '75 Q · 120–180',
      category: ExamCategory.internacionais,
      subject: 'Lógica & Direito · US',
      topic: 'LSAT · Logical Reasoning (Assumptions, Flaws, Weaken) & Reading Comp',
      summary: 'Seções sequenciais de Logical Reasoning seguidas de Reading Comprehension.',
      recommendedCount: 75,
      optionsFormat: '5 opções (A–E)',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/internacionais/lsat/lsat.md',
      icon: Icons.balance_rounded,
      accent: AsterConstants.ambar,
      sections: [
        ExamSectionSlice(name: 'Logical Reasoning', weight: 65),
        ExamSectionSlice(name: 'Reading Comprehension & Comparative', weight: 35),
      ],
    ),

    // ── Idiomas ─────────────────────────────────────────────────────────────
    ExamModelTemplate(
      id: 'ielts',
      name: 'IELTS (Academic/GT)',
      badge: 'Band 0–9 · 40 Q',
      category: ExamCategory.idiomas,
      subject: 'Inglês · IELTS',
      topic: 'IELTS Academic · Reading (T/F/NG, Matching) & Writing Task 1/2',
      summary: 'True/False/Not Given, Yes/No/Not Given e blocos progressivos de leitura acadêmica.',
      recommendedCount: 40,
      optionsFormat: 'Múltiplos formatos',
      difficulty: 'Médio / Prático',
      assetPath: 'exemplos_simulados/idiomas/ielts/ielts.md',
      icon: Icons.translate_rounded,
      accent: AsterConstants.menta,
      sections: [
        ExamSectionSlice(name: 'Reading Passage 1 · Factual & T/F/NG', weight: 33),
        ExamSectionSlice(name: 'Reading Passage 2 · Matching & Headings', weight: 33),
        ExamSectionSlice(name: 'Reading Passage 3 · Academic Argument & Y/N/NG', weight: 34),
      ],
    ),
    ExamModelTemplate(
      id: 'toefl',
      name: 'TOEFL iBT (ETS)',
      badge: '0–120',
      category: ExamCategory.idiomas,
      subject: 'Inglês · TOEFL',
      topic: 'TOEFL iBT · Academic Reading, Inference, Vocabulary & Academic Discussion',
      summary: 'Leitura acadêmica universitária americana, inserção de frases e síntese textual.',
      recommendedCount: 20,
      optionsFormat: '4 opções (A–D)',
      difficulty: 'Médio / Prático',
      assetPath: 'exemplos_simulados/idiomas/toefl/toefl.md',
      icon: Icons.record_voice_over_outlined,
      accent: AsterConstants.lavanda,
      sections: [
        ExamSectionSlice(name: 'Academic Reading · Factual & Vocabulary', weight: 50),
        ExamSectionSlice(name: 'Academic Reading · Inference & Prose Summary', weight: 50),
      ],
    ),
    ExamModelTemplate(
      id: 'cambridge_english',
      name: 'Cambridge B2/C1',
      badge: 'FCE / CAE · 52 Q',
      category: ExamCategory.idiomas,
      subject: 'Inglês · Cambridge',
      topic: 'Cambridge B2 First & C1 Advanced · Use of English & Reading',
      summary: 'Parts 1–4 Use of English seguidas de Parts 5–8 Reading.',
      recommendedCount: 52,
      optionsFormat: '4 opções / Cloze',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/idiomas/cambridge_english/cambridge_english.md',
      icon: Icons.spellcheck_rounded,
      accent: AsterConstants.ambar,
      sections: [
        ExamSectionSlice(name: 'Use of English (Cloze, Word Formation, Transformations)', weight: 55),
        ExamSectionSlice(name: 'Reading Comprehension & Cross-Text Matching', weight: 45),
      ],
    ),
    ExamModelTemplate(
      id: 'dele',
      name: 'DELE (Espanhol)',
      badge: 'B1–C1 · 36 Q',
      category: ExamCategory.idiomas,
      subject: 'Espanhol · Cervantes',
      topic: 'DELE B1/B2/C1 · Comprensión de Lectura, Léxico/Subjuntivo e EIE',
      summary: 'Compreensão de leitura seguida de uso da língua (léxico/subjuntivo) em 3 opções.',
      recommendedCount: 36,
      optionsFormat: '3 opções (A–C)',
      difficulty: 'Médio / Prático',
      assetPath: 'exemplos_simulados/idiomas/dele/dele.md',
      icon: Icons.language_rounded,
      accent: AsterConstants.coral,
      sections: [
        ExamSectionSlice(name: 'Comprensión de Lectura (Tareas 1–3)', weight: 60),
        ExamSectionSlice(name: 'Léxico, Subjuntivo y Conectores (Tarea 4)', weight: 40),
      ],
    ),
    ExamModelTemplate(
      id: 'delf_dalf',
      name: 'DELF / DALF (Francês)',
      badge: 'B1 / B2 / C1',
      category: ExamCategory.idiomas,
      subject: 'Francês · FEI',
      topic: 'DELF B2 & DALF C1 · Compréhension des écrits (QCM) & Argumentation',
      summary: 'Textos informativos seguidos de textos argumentativos e análise de nuance.',
      recommendedCount: 25,
      optionsFormat: '3 opções (A–C)',
      difficulty: 'Médio / Prático',
      assetPath: 'exemplos_simulados/idiomas/delf_dalf/delf_dalf.md',
      icon: Icons.forum_outlined,
      accent: AsterConstants.lavanda,
      sections: [
        ExamSectionSlice(name: 'Compréhension · Texte Informatif', weight: 50),
        ExamSectionSlice(name: 'Compréhension · Texte Argumentatif & Nuance', weight: 50),
      ],
    ),
    ExamModelTemplate(
      id: 'goethe_zertifikat',
      name: 'Goethe-Zertifikat',
      badge: 'Alemão · 30 Q',
      category: ExamCategory.idiomas,
      subject: 'Alemão · Goethe',
      topic: 'Goethe-Zertifikat B1/B2/C1 · Lesen (Teile 1–5) & Schreiben',
      summary: 'Modellsatz modular sequencial: Lesen Teile 1–2 -> Teile 3–5.',
      recommendedCount: 30,
      optionsFormat: '3–4 opções / Match',
      difficulty: 'Médio / Prático',
      assetPath: 'exemplos_simulados/idiomas/goethe_zertifikat/goethe_zertifikat.md',
      icon: Icons.auto_stories_outlined,
      accent: AsterConstants.ambar,
      sections: [
        ExamSectionSlice(name: 'Lesen · Forum & Textschichtung (Teile 1–2)', weight: 50),
        ExamSectionSlice(name: 'Lesen · Sachtext & Ordnungen (Teile 3–5)', weight: 50),
      ],
    ),
    ExamModelTemplate(
      id: 'jlpt',
      name: 'JLPT (Japonês)',
      badge: 'N5 a N1',
      category: ExamCategory.idiomas,
      subject: 'Japonês · JLPT',
      topic: 'JLPT N5–N1 · Kanji, Vocabulário, Ordenação [ ★ ], Gramática e Dokkai',
      summary: 'Seções oficiais em ordem: Kanji/Vocabulário -> Gramática & [ ★ ] -> Leitura (Dokkai).',
      recommendedCount: 45,
      optionsFormat: '4 opções (1–4)',
      difficulty: 'Médio / Prático',
      assetPath: 'exemplos_simulados/idiomas/jlpt/jlpt.md',
      icon: Icons.translate_rounded,
      accent: AsterConstants.coral,
      sections: [
        ExamSectionSlice(name: '言語知識 · 文字・語彙 (Kanji e Vocabulário)', weight: 35),
        ExamSectionSlice(name: '言語知識 · 文法 (Gramática e Ordenação [ ★ ])', weight: 35),
        ExamSectionSlice(name: '読解 (Compreensão de Leitura / Dokkai)', weight: 30),
      ],
    ),
    ExamModelTemplate(
      id: 'hsk',
      name: 'HSK (Mandarim)',
      badge: 'HSK 1–6',
      category: ExamCategory.idiomas,
      subject: 'Mandarim · HSK',
      topic: 'HSK 1–6 · Caracteres Simplificados, Lacunas, Ordenação e 病句',
      summary: 'Seções sequenciais: Vocabulário/Lacunas -> Ordenação/Sintaxe -> Leitura.',
      recommendedCount: 40,
      optionsFormat: '4 opções (A–D)',
      difficulty: 'Médio / Prático',
      assetPath: 'exemplos_simulados/idiomas/hsk/hsk.md',
      icon: Icons.chat_bubble_outline_rounded,
      accent: AsterConstants.menta,
      sections: [
        ExamSectionSlice(name: 'Vocabulário & Lacunas (选词填空)', weight: 35),
        ExamSectionSlice(name: 'Sintaxe, Ordenação & 病句', weight: 30),
        ExamSectionSlice(name: 'Compreensão de Leitura (阅读理解)', weight: 35),
      ],
    ),
    ExamModelTemplate(
      id: 'celpe_bras',
      name: 'Celpe-Bras',
      badge: 'Português · INEP',
      category: ExamCategory.idiomas,
      subject: 'Português · Celpe-Bras',
      topic: 'Celpe-Bras · Tarefas Comunicativas, Gêneros Textuais e Registro',
      summary: 'Análise de adequação a gênero, interlocutor, propósito e registro brasileiro.',
      recommendedCount: 15,
      optionsFormat: 'Cenários & Análise',
      difficulty: 'Médio / Prático',
      assetPath: 'exemplos_simulados/idiomas/celpe_bras/celpe_bras.md',
      icon: Icons.edit_note_rounded,
      accent: AsterConstants.menta,
      sections: [
        ExamSectionSlice(name: 'Gêneros Discursivos & Registro', weight: 50),
        ExamSectionSlice(name: 'Compreensão & Integração de Insumos', weight: 50),
      ],
    ),

    // ── Jurídico & Concursos ────────────────────────────────────────────────
    ExamModelTemplate(
      id: 'oab',
      name: 'OAB Unificado',
      badge: 'FGV · 80 Q',
      category: ExamCategory.juridico,
      subject: 'Direito · OAB',
      topic: 'Exame de Ordem OAB (FGV) · Casos Concretos e Legislação Vigente',
      summary: '80 questões divididas em blocos por ramo do Direito (Ética -> Const. -> Civil -> Penal...).',
      recommendedCount: 80,
      optionsFormat: '4 opções (A–D)',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/juridico_e_concursos/oab/oab.md',
      icon: Icons.gavel_rounded,
      accent: AsterConstants.coral,
      sections: [
        ExamSectionSlice(name: 'Ética Profissional & Estatuto da OAB', weight: 10),
        ExamSectionSlice(name: 'Direito Constitucional & Direitos Humanos', weight: 15),
        ExamSectionSlice(name: 'Direito Administrativo & Ambiental', weight: 12),
        ExamSectionSlice(name: 'Direito Civil & Empresarial', weight: 18),
        ExamSectionSlice(name: 'Direito Processual Civil', weight: 10),
        ExamSectionSlice(name: 'Direito Penal & Processual Penal', weight: 18),
        ExamSectionSlice(name: 'Direito do Trabalho, Proc. Trabalho & Tributário', weight: 17),
      ],
    ),
    ExamModelTemplate(
      id: 'concursos_publicos',
      name: 'Concursos Públicos',
      badge: 'Cebraspe 120 Q',
      category: ExamCategory.juridico,
      subject: 'Concursos · Brasil',
      topic: 'Concursos Públicos (CEBRASPE Certo/Errado, FGV Casos & Cesgranrio/CNU)',
      summary: 'Caderno dividido em Conhecimentos Básicos (Português/Const/Adm) e Específicos.',
      recommendedCount: 120,
      optionsFormat: 'Certo/Errado ou A–E',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/juridico_e_concursos/concursos_publicos/concursos_publicos.md',
      icon: Icons.account_balance_rounded,
      accent: AsterConstants.lavanda,
      sections: [
        ExamSectionSlice(name: 'Língua Portuguesa & Interpretação', weight: 22),
        ExamSectionSlice(name: 'Direito Constitucional', weight: 20),
        ExamSectionSlice(name: 'Direito Administrativo & Licitações', weight: 20),
        ExamSectionSlice(name: 'Raciocínio Lógico & Informática', weight: 15),
        ExamSectionSlice(name: 'Conhecimentos Específicos & Políticas Públicas', weight: 23),
      ],
    ),
    ExamModelTemplate(
      id: 'enam',
      name: 'ENAM (Magistratura)',
      badge: 'ENFAM · 80 Q',
      category: ExamCategory.juridico,
      subject: 'Magistratura · ENAM',
      topic: 'ENAM (FGV/ENFAM) · 8 Ramos Jurídicos, STF/STJ e Formação Humanística',
      summary: 'Distribuição exata das 8 disciplinas da prova oficial em blocos sequenciais.',
      recommendedCount: 80,
      optionsFormat: '5 opções (A–E)',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/juridico_e_concursos/enam/enam.md',
      icon: Icons.balance_outlined,
      accent: AsterConstants.coral,
      sections: [
        ExamSectionSlice(name: 'Direito Constitucional', weight: 20),
        ExamSectionSlice(name: 'Direito Administrativo', weight: 12.5),
        ExamSectionSlice(name: 'Noções Gerais e Formação Humanística', weight: 7.5),
        ExamSectionSlice(name: 'Direitos Humanos', weight: 7.5),
        ExamSectionSlice(name: 'Direito Processual Civil', weight: 15),
        ExamSectionSlice(name: 'Direito Civil', weight: 15),
        ExamSectionSlice(name: 'Direito Empresarial', weight: 7.5),
        ExamSectionSlice(name: 'Direito Penal', weight: 15),
      ],
    ),
    ExamModelTemplate(
      id: 'enade_direito',
      name: 'ENADE Direito',
      badge: 'INEP · 40 Q',
      category: ExamCategory.juridico,
      subject: 'Direito · ENADE',
      topic: 'ENADE Direito · Formação Geral, Asserção-Razão e Eixo Jurídico',
      summary: 'Bloco de Formação Geral (25%) seguido do Componente Específico Jurídico (75%).',
      recommendedCount: 40,
      optionsFormat: '5 opções (A–E)',
      difficulty: 'Médio / Prático',
      assetPath: 'exemplos_simulados/juridico_e_concursos/enade_direito/enade_direito.md',
      icon: Icons.menu_book_outlined,
      accent: AsterConstants.ambar,
      sections: [
        ExamSectionSlice(name: 'Formação Geral', weight: 25),
        ExamSectionSlice(name: 'Componente Específico · Direito', weight: 75),
      ],
    ),

    // ── Saúde & Medicina ────────────────────────────────────────────────────
    ExamModelTemplate(
      id: 'revalida',
      name: 'REVALIDA (INEP)',
      badge: '100 Q · SUS',
      category: ExamCategory.saude,
      subject: 'Medicina · REVALIDA',
      topic: 'REVALIDA INEP · 5 Grandes Áreas Médicas e Atenção Primária/SUS',
      summary: 'Dividido sequencialmente nas 5 Grandes Áreas: Clínica, Cirurgia, GO, Pediatria e Preventiva.',
      recommendedCount: 100,
      optionsFormat: '4 opções (A–D)',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/saude_e_medicina/revalida/revalida.md',
      icon: Icons.local_hospital_outlined,
      accent: AsterConstants.menta,
      sections: [
        ExamSectionSlice(name: 'Clínica Médica', weight: 20),
        ExamSectionSlice(name: 'Cirurgia Geral', weight: 20),
        ExamSectionSlice(name: 'Ginecologia e Obstetrícia', weight: 20),
        ExamSectionSlice(name: 'Pediatria', weight: 20),
        ExamSectionSlice(name: 'Medicina Preventiva e Saúde Coletiva (SUS)', weight: 20),
      ],
    ),
    ExamModelTemplate(
      id: 'enare',
      name: 'ENARE Residência',
      badge: 'Ebserh · 100 Q',
      category: ExamCategory.saude,
      subject: 'Residência Médica',
      topic: 'ENARE Acesso Direto (Ebserh/FGV) · 5 Grandes Áreas e Protocolos MS',
      summary: 'Caderno em 5 blocos de 20 questões: Clínica, Cirurgia, GO, Pediatria e Preventiva.',
      recommendedCount: 100,
      optionsFormat: '5 opções (A–E)',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/saude_e_medicina/enare/enare.md',
      icon: Icons.medical_services_outlined,
      accent: AsterConstants.lavanda,
      sections: [
        ExamSectionSlice(name: 'Clínica Médica', weight: 20),
        ExamSectionSlice(name: 'Cirurgia Geral', weight: 20),
        ExamSectionSlice(name: 'Ginecologia e Obstetrícia', weight: 20),
        ExamSectionSlice(name: 'Pediatria', weight: 20),
        ExamSectionSlice(name: 'Medicina Preventiva e Social (SUS)', weight: 20),
      ],
    ),
    ExamModelTemplate(
      id: 'usmle',
      name: 'USMLE Step 1 / 2 CK',
      badge: 'NBME · 40 Q/bloco',
      category: ExamCategory.saude,
      subject: 'Medicine · USMLE',
      topic: 'USMLE Step 1 & Step 2 CK · Clinical Vignettes & Next Step in Management',
      summary: 'Vinhetas NBME em inglês organizadas por sistema/fisiopatologia e conduta.',
      recommendedCount: 40,
      optionsFormat: '5 opções (A–E)',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/saude_e_medicina/usmle/usmle.md',
      icon: Icons.health_and_safety_outlined,
      accent: AsterConstants.coral,
      sections: [
        ExamSectionSlice(name: 'Pathophysiology & Basic Sciences (Step 1)', weight: 35),
        ExamSectionSlice(name: 'Internal Medicine & Clinical Diagnosis', weight: 35),
        ExamSectionSlice(name: 'Next Step in Management & Preventive Care', weight: 30),
      ],
    ),

    // ── Finanças & Economia ─────────────────────────────────────────────────
    ExamModelTemplate(
      id: 'anbima_e_cfa',
      name: 'ANBIMA & CFA Level I',
      badge: 'CPA / CFA',
      category: ExamCategory.financas,
      subject: 'Mercado Financeiro',
      topic: 'ANBIMA (CPA, C-Pro R/I, CVM 175) & CFA Level I (Ethics, FSA, Fixed Income)',
      summary: 'Blocos sequenciais: Ética/Compliance -> Economia -> Produtos/Valuation -> Tributação.',
      recommendedCount: 60,
      optionsFormat: '4 alt (ANBIMA) / 3 (CFA)',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/negocios_financas_e_economia/anbima_e_cfa/anbima_e_cfa.md',
      icon: Icons.trending_up_rounded,
      accent: AsterConstants.ambar,
      sections: [
        ExamSectionSlice(name: 'Ética, Compliance, Suitability & PLDFT', weight: 25),
        ExamSectionSlice(name: 'Economia, SFN & Métodos Quantitativos', weight: 20),
        ExamSectionSlice(name: 'Renda Fixa, Variável, Fundos (CVM 175) & Derivativos', weight: 35),
        ExamSectionSlice(name: 'Tributação & Gestão de Portfólios', weight: 20),
      ],
    ),
    ExamModelTemplate(
      id: 'anpec',
      name: 'ANPEC Economia',
      badge: '75 Itens V/F',
      category: ExamCategory.financas,
      subject: 'Economia · Pós-Grad',
      topic: 'ANPEC · Microeconomia, Macroeconomia, Matemática, Estatística e Econ. Brasileira',
      summary: 'Caderno dividido em blocos iguais: Micro, Macro, Matemática, Estatística e Econ. BR.',
      recommendedCount: 75,
      optionsFormat: 'V/F ou 4–5 opções',
      difficulty: 'Avançado / Nível Certificação',
      assetPath: 'exemplos_simulados/negocios_financas_e_economia/anpec/anpec.md',
      icon: Icons.show_chart_rounded,
      accent: AsterConstants.lavanda,
      sections: [
        ExamSectionSlice(name: 'Microeconomia', weight: 20),
        ExamSectionSlice(name: 'Macroeconomia', weight: 20),
        ExamSectionSlice(name: 'Matemática', weight: 20),
        ExamSectionSlice(name: 'Estatística e Econometria', weight: 20),
        ExamSectionSlice(name: 'Economia Brasileira', weight: 20),
      ],
    ),
  ];

  static const List<String> _popularOrderIds = [
    'enem',
    'fuvest',
    'unicamp',
    'unesp',
    'oab',
    'concursos_publicos',
    'toefl',
    'ielts',
    'sat',
    'ita',
    'encceja',
    'cambridge_english',
    'dele',
    'delf_dalf',
    'enare',
    'revalida',
    'usmle',
    'act',
    'gre',
    'gmat',
    'lsat',
    'anbima_e_cfa',
    'enam',
    'enade_direito',
    'comptia_security_plus',
    'cloud_e_certificacoes',
    'microsoft_azure',
    'google_cloud',
    'kubernetes_cncf',
    'owasp_appsec',
    'cisco_ccna',
    'goethe_zertifikat',
    'jlpt',
    'hsk',
    'celpe_bras',
    'anpec',
    'poscomp',
    'enade_computacao',
    'obi',
  ];

  static final List<ExamModelTemplate> _popularOrderedAll = _buildPopularOrderedAll();

  static List<ExamModelTemplate> _buildPopularOrderedAll() {
    final rankById = <String, int>{
      for (int i = 0; i < _popularOrderIds.length; i++) _popularOrderIds[i]: i,
    };
    final list = List<ExamModelTemplate>.from(models);
    list.sort((a, b) {
      final rankA = rankById[a.id] ?? 9999;
      final rankB = rankById[b.id] ?? 9999;
      return rankA.compareTo(rankB);
    });
    return List<ExamModelTemplate>.unmodifiable(list);
  }

  static List<ExamModelTemplate> byCategory(ExamCategory category) {
    if (category == ExamCategory.all) return _popularOrderedAll;
    return models.where((m) => m.category == category).toList();
  }

  static Future<String?> loadBlueprint(ExamModelTemplate model) async {
    if (_blueprintCache.containsKey(model.id)) {
      return _blueprintCache[model.id];
    }
    try {
      final content = await rootBundle.loadString(model.assetPath);
      _blueprintCache[model.id] = content;
      return content;
    } catch (_) {
      return null;
    }
  }
}
