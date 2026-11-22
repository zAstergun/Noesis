import 'dart:convert';

/// Reusable mock fixtures for E2E tests:
/// study sessions, calendar events, RAG text, and quiz JSON payloads.
class TestFixtures {
  /// Standard mock study sessions
  static List<Map<String, dynamic>> mockStudySessions() {
    return [
      {
        'id': 'sess-001',
        'user_id': 'user-123',
        'subject': 'Criptografia',
        'topic': 'AES-GCM & Nonce Reuse',
        'duration_minutes': 90,
        'study_date': DateTime.now().toIso8601String().split('T').first,
        'notes': 'Análise de integridade de autenticação e criptografia simétrica.',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'sess-002',
        'user_id': 'user-123',
        'subject': 'Redes & Protocolos',
        'topic': 'TCP Handshake & TLS 1.3',
        'duration_minutes': 60,
        'study_date': DateTime.now().subtract(const Duration(days: 1)).toIso8601String().split('T').first,
        'notes': 'Diferença de round-trips entre TLS 1.2 e 1.3 (0-RTT).',
        'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'id': 'sess-003',
        'user_id': 'user-123',
        'subject': 'Cloud Security',
        'topic': 'AWS IAM Roles & Policies',
        'duration_minutes': 120,
        'study_date': DateTime.now().subtract(const Duration(days: 2)).toIso8601String().split('T').first,
        'notes': 'Princípio do menor privilégio e permissões boundary.',
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      },
    ];
  }

  /// Single sample study session
  static Map<String, dynamic> singleStudySession({
    String id = 'sess-new-1',
    String subject = 'Sistemas Operacionais',
    String topic = 'Gerenciamento de Memória Virtual',
    int durationMinutes = 75,
  }) {
    return {
      'id': id,
      'user_id': 'guest-user',
      'subject': subject,
      'topic': topic,
      'duration_minutes': durationMinutes,
      'study_date': DateTime.now().toIso8601String().split('T').first,
      'notes': 'Paging, TLB e page fault handling.',
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  /// Standard mock calendar events
  static List<Map<String, dynamic>> mockCalendarEvents() {
    final now = DateTime.now();
    return [
      {
        'id': 'evt-001',
        'user_id': 'user-123',
        'title': 'Revisão Espaçada: Criptografia',
        'description': 'Revisão dos modos de cifra em bloco ECB vs CBC vs GCM.',
        'category': 'study',
        'color': '#7C6CF0',
        'start_time': now.add(const Duration(hours: 2)).toIso8601String(),
        'end_time': now.add(const Duration(hours: 3, minutes: 30)).toIso8601String(),
        'is_completed': false,
        'created_at': now.toIso8601String(),
      },
      {
        'id': 'evt-002',
        'user_id': 'user-123',
        'title': 'Lab OWASP Top 10: SQL Injection',
        'description': 'Ambiente prático com exploração e remediação.',
        'category': 'lab',
        'color': '#3CCF9A',
        'start_time': now.add(const Duration(days: 1, hours: 1)).toIso8601String(),
        'end_time': now.add(const Duration(days: 1, hours: 3)).toIso8601String(),
        'is_completed': true,
        'created_at': now.toIso8601String(),
      },
      {
        'id': 'evt-003',
        'user_id': 'user-123',
        'title': 'Simulado CompTIA Security+ SY0-701',
        'description': '90 questões em tempo cronometrado.',
        'category': 'exam',
        'color': '#FF7A90',
        'start_time': now.add(const Duration(days: 3)).toIso8601String(),
        'end_time': now.add(const Duration(days: 3, hours: 2)).toIso8601String(),
        'is_completed': false,
        'created_at': now.toIso8601String(),
      },
    ];
  }

  /// Sample RAG text document
  static const String sampleRagDocument = '''
# CompTIA Security+ SY0-701: Guia Oficial de Criptografia

## 1. Modos de Operação de Cifras em Bloco
O AES (Advanced Encryption Standard) opera em blocos fixos de 128 bits.
- **ECB (Electronic Codebook)**: Cada bloco de 128 bits de texto claro é criptografado independentemente. Nunca deve ser utilizado para mais de um bloco de dados, pois preserva padrões visuais no texto cifrado.
- **CBC (Cipher Block Chaining)**: Cada bloco de texto claro é submetido a uma operação XOR com o bloco cifrado anterior antes de ser criptografado. Requer um vetor de inicialização (IV) aleatório e imprevisível.
- **GCM (Galois/Counter Mode)**: Combina o modo CTR (Counter) com autenticação Galois, provendo confidencialidade, integridade e autenticação de dados (AEAD). O reuso de nonce no AES-GCM compromete catastroficamente a chave de autenticação.

## 2. Protocolos Seguros de Transporte
- **TLS 1.3** elimina cifras vulneráveis (como RC4 e DES), remove o suporte a trocas estáticas de chaves RSA e acelera o handshake para 1-RTT (ou 0-RTT com retomada de sessão segura).
''';

  /// Standard AI Quiz JSON response
  static String validQuizJson() {
    return jsonEncode([
      {
        'id': 1,
        'question': 'Qual é a principal vulnerabilidade associada ao modo de operação ECB (Electronic Codebook) no AES?',
        'code_snippet': 'cipher = AES.new(key, AES.MODE_ECB)',
        'options': [
          'Ele requer um vetor de inicialização (IV) excessivamente longo',
          'Blocos idênticos de texto claro produzem blocos idênticos de texto cifrado, preservando padrões',
          'Ele é incompatível com chaves de 256 bits',
          'Ele consome mais processamento que o modo GCM'
        ],
        'correct_index': 1,
        'explanation': 'O modo ECB cifra cada bloco independentemente, revelando padrões estruturais do texto claro.',
        'rag_source': 'CompTIA Security+ SY0-701: Seção 1 (ECB)'
      },
      {
        'id': 2,
        'question': 'Qual modo provê criptografia autenticada com dados associados (AEAD)?',
        'code_snippet': null,
        'options': [
          'CBC',
          'CFB',
          'OFB',
          'GCM'
        ],
        'correct_index': 3,
        'explanation': 'O Galois/Counter Mode (GCM) une cifra de fluxo baseada em contador com autenticação Galois (MAC).',
        'rag_source': 'CompTIA Security+ SY0-701: Seção 1 (GCM)'
      },
      {
        'id': 3,
        'question': 'Qual melhoria primordial foi introduzida no handshake do TLS 1.3?',
        'code_snippet': 'curl --tlsv1.3 https://api.noesis.asterdev.me',
        'options': [
          'Redução do handshake completo para 1-RTT e remoção de algoritmos legados',
          'Reintrodução de troca de chaves RSA pura',
          'Suporte nativo a cifras MD5 e SHA-1',
          'Obrigatoriedade de autenticação de dois fatores no protocolo'
        ],
        'correct_index': 0,
        'explanation': 'TLS 1.3 corta um ciclo de ida e volta (1-RTT) e descarta algoritmos inseguros.',
        'rag_source': 'CompTIA Security+ SY0-701: Seção 2 (TLS 1.3)'
      }
    ]);
  }

  /// Quiz JSON wrapped in markdown fences
  static String markdownFencedQuizJson() {
    return '```json\n${validQuizJson()}\n```';
  }

  /// Nested format Quiz JSON
  static String nestedQuizJson() {
    return jsonEncode({
      'version': '1.0',
      'topic': 'Criptografia',
      'questions': [
        {
          'id': 1,
          'question': 'O que ocorre se um nonce for reutilizado no AES-GCM?',
          'code_snippet': null,
          'options': [
            'Ocorre erro de timeout na transmissão',
            'A chave de autenticação pode ser recuperada matematicamente',
            'O tamanho do arquivo cifrado dobra',
            'Nada ocorre, pois o IV compensa o nonce'
          ],
          'correct_index': 1,
          'explanation': 'No AES-GCM, o reuso de nonce com a mesma chave destrói a garantia de autenticidade (GHASH key recovery).',
          'rag_source': 'RAG Guia Oficial: Seção 1'
        }
      ]
    });
  }

  /// Malformed Quiz JSON string
  static const String malformedQuizJson = '''
  [
    {"id": 1, "question": "Incomplete JSON, missing closing braces...
  ''';

  /// Standard mock user profile
  static Map<String, dynamic> mockUserProfile({
    String id = 'user-test-uuid',
    String fullName = 'Victor Torres',
    String channel = 'Security Engineer',
    String? avatarUrl,
  }) {
    return {
      'id': id,
      'full_name': fullName,
      'channel': channel,
      'avatar_url': avatarUrl,
      'streak_days': 42,
      'level': 14,
    };
  }
}
