import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:noesis/core/localization/noesis_l10n.dart';
import 'package:noesis/core/localization/noesis_locale_service.dart';
import 'package:noesis/core/notifications_service.dart';
import 'package:noesis/core/shop_service.dart';
import 'package:noesis/core/supabase_service.dart';
import 'package:noesis/core/theme.dart';
import 'package:noesis/features/profile/data/social_connections_service.dart';
import 'package:noesis/features/ranking/data/ranking_service.dart';
import 'package:noesis/features/study_groups/data/study_groups_service.dart';
import 'package:noesis/main.dart';
import '../../harness/mock_http_overrides.dart';
import '../../harness/test_app_harness.dart';

/// Shared hermetic test helpers for the Noesis 15-language localization & RTL E2E suite.
class LocalizationTestHelpers {
  LocalizationTestHelpers._();

  /// Canonical 15 Aster ecosystem language codes in registry order.
  static List<String> get all15LanguageCodes => const <String>[
        'br',
        'en',
        'es',
        'jp',
        'cn',
        'kr',
        'vn',
        'id',
        'fr',
        'de',
        'it',
        'nl',
        'ru',
        'ar',
        'pt',
      ];

  /// Initializes the hermetic test environment, preloads intl date symbols
  /// for all 15 supported languages, drains pending fonts, and resets state.
  static Future<void> setUpSuite() async {
    await TestAppHarness.setUpTestEnvironment();
    for (final lang in NoesisLocaleService.supportedLanguages) {
      await NoesisLocaleService.ensureDateFormattingInitialized(lang.intlLocale);
    }
    await GoogleFonts.pendingFonts();
    await resetState();
  }

  /// Resets all app/service/locale singletons to a clean deterministic state.
  static Future<void> resetState({
    String? initialCode,
    NoesisLocaleSource initialSource = NoesisLocaleSource.auto,
    List<Locale>? platformLocalesOverride,
    bool clearStoredPreference = true,
  }) async {
    MockHttpOverrides.reset();
    MockHttpOverrides.install();

    RootScreen.bypassAuthForTesting = true;
    RootScreen.isWebOverrideForTesting = null;

    AsterTheme.selectThemeOption('soft_clay_nevoa');
    AsterTheme.setThemeMode(ThemeMode.light);
    await AsterTheme.resetCustomThemeForTesting();

    await NotificationsService.instance.resetForTesting();
    await ShopService.instance.resetForTesting();
    RankingService.allowSyntheticPeersForTesting = false;
    await RankingService.instance.resetForTesting();
    await StudyGroupsService.instance.resetForTesting();
    await SocialConnectionsService.instance.resetForTesting();
    await SupabaseService.resetConsistencyForTesting();

    if (clearStoredPreference) {
      await SupabaseService.resetProfileForTesting();
    }

    await NoesisLocaleService.resetForTesting(
      initialCode: initialCode,
      initialSource: initialSource,
      platformLocalesOverride: platformLocalesOverride,
      clearStoredPreference: clearStoredPreference,
    );
  }

  /// Pumps [NoesisApp] directly (without nested MaterialApp wrappers) using
  /// [TestAppHarness]'s viewport sizing, error filter, teardown restoration,
  /// and async/font draining without `pumpAndSettle()`.
  static Future<void> pumpNoesisApp(
    WidgetTester tester, {
    Size screenSize = const Size(1280, 800),
    List<Locale>? platformLocalesOverride,
  }) async {
    if (platformLocalesOverride != null) {
      NoesisLocaleService.platformLocalesOverrideForTesting =
          platformLocalesOverride;
      await NoesisLocaleService.ensureInitialized(forceReload: true);
    }

    final originalOnError = FlutterError.onError;
    FlutterError.onError = _filteredErrorHandler(originalOnError);

    tester.view.physicalSize = screenSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      FlutterError.onError = originalOnError;
    });

    await tester.pumpWidget(const NoesisApp());
    await tester.pump();
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    await GoogleFonts.pendingFonts();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Pumps [screen] inside [TestAppHarness], synchronizing [NoesisLocaleService]
  /// and intl date formatting when [locale] differs from `pt_BR`.
  static Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Size screenSize = const Size(1280, 800),
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = const Locale('pt', 'BR'),
  }) async {
    if (locale == const Locale('pt', 'BR')) {
      await TestAppHarness.pumpInHarness(
        tester,
        screen,
        themeMode: themeMode,
        screenSize: screenSize,
      );
      return;
    }

    final tag = <String>[
      locale.languageCode,
      if (locale.scriptCode != null && locale.scriptCode!.isNotEmpty)
        locale.scriptCode!,
      if (locale.countryCode != null && locale.countryCode!.isNotEmpty)
        locale.countryCode!,
    ].join('-');
    final normalizedCode =
        NoesisLocaleService.normalizeCode(tag) ??
        NoesisLocaleService.defaultFallbackCode;

    await NoesisLocaleService.resetForTesting(
      initialCode: normalizedCode,
      clearStoredPreference: false,
    );
    await NoesisLocaleService.ensureDateFormattingInitialized(
      NoesisLocaleService.optionForCode(normalizedCode).intlLocale,
    );

    final originalOnError = FlutterError.onError;
    FlutterError.onError = _filteredErrorHandler(originalOnError);

    tester.view.physicalSize = screenSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      FlutterError.onError = originalOnError;
    });

    await tester.pumpWidget(
      TestAppHarness.wrapWidget(
        screen,
        themeMode: themeMode,
        screenSize: screenSize,
        locale: locale,
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    await GoogleFonts.pendingFonts();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  static FlutterExceptionHandler _filteredErrorHandler(
    FlutterExceptionHandler? originalOnError,
  ) {
    return (FlutterErrorDetails details) {
      final msg = details.exceptionAsString();
      if (msg.contains(
            'ListTile background color or ink splashes may be invisible',
          ) ||
          msg.contains('A RenderFlex overflowed by')) {
        return;
      }
      originalOnError?.call(details);
    };
  }

  /// Locates the Noesis repository root directory by walking up to `pubspec.yaml`.
  static Directory projectRoot() {
    var dir = Directory.current.absolute;
    while (true) {
      final pubspec = File('${dir.path}${Platform.pathSeparator}pubspec.yaml');
      if (pubspec.existsSync()) {
        return dir;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) {
        break;
      }
      dir = parent;
    }
    return Directory.current.absolute;
  }

  /// Reads a file under [projectRoot] given a forward- or backslash-delimited [relativePath].
  static String readProjectFile(String relativePath) {
    final normalized = _normalizeRelativePath(relativePath);
    final file = File(
      '${projectRoot().path}${Platform.pathSeparator}$normalized',
    );
    if (!file.existsSync()) {
      throw FileSystemException(
        'Project file not found: $relativePath',
        file.path,
      );
    }
    return file.readAsStringSync();
  }

  /// Lists all `.dart` files recursively under [relativeDir], sorted deterministically by path.
  static List<File> listDartFilesUnder(String relativeDir) {
    final normalized = _normalizeRelativePath(relativeDir);
    final dir = Directory(
      '${projectRoot().path}${Platform.pathSeparator}$normalized',
    );
    if (!dir.existsSync()) {
      return const <File>[];
    }
    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  static String _normalizeRelativePath(String relativePath) {
    var clean = relativePath
        .replaceAll('\\', Platform.pathSeparator)
        .replaceAll('/', Platform.pathSeparator);
    while (clean.startsWith(Platform.pathSeparator)) {
      clean = clean.substring(1);
    }
    return clean;
  }

  /// Returns an immutable view of all 15 compiled translation maps from [NoesisL10n.translations].
  static Map<String, Map<String, String>> parseTranslationMaps() {
    return <String, Map<String, String>>{
      for (final entry in NoesisL10n.translations.entries)
        entry.key: Map<String, String>.unmodifiable(entry.value),
    };
  }

  static final List<RegExp> _portuguesePhrasePatterns = <RegExp>[
    RegExp(
      r'As tradu[çc][õo]es completas est[ãa]o em desenvolvimento',
      caseSensitive: false,
    ),
    RegExp(
      r'Sua sele[çc][ãa]o fica registrada no perfil',
      caseSensitive: false,
    ),
    RegExp(r'Idioma e Regi[ãa]o', caseSensitive: false),
    RegExp(r'Acessar ferramenta', caseSensitive: false),
    RegExp(r'Entrar na Aster Account', caseSensitive: false),
    RegExp(r'Di[áa]rio de Estudos?', caseSensitive: false),
    RegExp(r'Tudo em dia', caseSensitive: false),
    RegExp(r'Marcar lidas', caseSensitive: false),
    RegExp(r'Meta Semanal', caseSensitive: false),
    RegExp(r'Meta Diária', caseSensitive: false),
    RegExp(r'Simulado Oficial', caseSensitive: false),
    RegExp(r'Modo Livre', caseSensitive: false),
    RegExp(r'Editar Perfil', caseSensitive: false),
    RegExp(r'Entrar com C[óo]digo', caseSensitive: false),
    RegExp(r'Criar Grupo', caseSensitive: false),
    RegExp(r'Trilha de Estudos', caseSensitive: false),
    RegExp(r'Novo Baralho', caseSensitive: false),
    RegExp(r'Para Revisar', caseSensitive: false),
    RegExp(r'Esqueceu a senha', caseSensitive: false),
    RegExp(r'E-mail ou senha incorretos', caseSensitive: false),
    RegExp(r'Confirme seu e-mail', caseSensitive: false),
    RegExp(r'Chave de IA n[ãa]o configurada', caseSensitive: false),
    RegExp(r'Login conclu[íi]do no Noesis', caseSensitive: false),
    RegExp(r'N[ãa]o foi poss[íi]vel concluir o login', caseSensitive: false),
    RegExp(r'ORDEM SEQUENCIAL OBRIGAT[ÓO]RIA', caseSensitive: false),
    RegExp(r'obrigatoriamente da disciplina', caseSensitive: false),
    RegExp(r'configure sua chave de API', caseSensitive: false),
    RegExp(r'B[ôo]nus de boas-vindas', caseSensitive: false),
    RegExp(r'Primeiro Passo', caseSensitive: false),
    RegExp(r'N[ée]voa do Elo', caseSensitive: false),
    RegExp(r'Discord do Aster', caseSensitive: false),
    RegExp(r'Plano de estudo de hoje', caseSensitive: false),
    RegExp(r'Conquista desbloqueada', caseSensitive: false),
    RegExp(r'Mundo [ÁA]rabe', caseSensitive: false),
    RegExp(r'Coreia do Sul', caseSensitive: false),
    RegExp(r'\bem Portugu[êe]s\b', caseSensitive: false),
    RegExp(r'Dif[íi]cil\s*[·•]\s*refor[çc]ar', caseSensitive: false),
    RegExp(r'\ba fazer\b', caseSensitive: false),
    RegExp(r'\bsem dados\b', caseSensitive: false),
    RegExp(r'\bsem resultados?\b', caseSensitive: false),
    RegExp(r'\bsem meta\b', caseSensitive: false),
    RegExp(r'\btodos os\b', caseSensitive: false),
    RegExp(r'\btodas as\b', caseSensitive: false),
    RegExp(r'\btaxa de\b', caseSensitive: false),
    RegExp(r'\bprotetor de\b', caseSensitive: false),
    RegExp(r'\bcriar conta\b', caseSensitive: false),
    RegExp(r'\bescolha uma?\b', caseSensitive: false),
    RegExp(r'\bbom dia\b', caseSensitive: false),
    RegExp(r'\bboa tarde\b', caseSensitive: false),
    RegExp(r'\bboa noite\b', caseSensitive: false),
    RegExp(r'\bcom sucesso\b', caseSensitive: false),
    RegExp(r'\bem andamento\b', caseSensitive: false),
    RegExp(r'\bem processamento\b', caseSensitive: false),
    RegExp(r'\bnova tarefa\b', caseSensitive: false),
    RegExp(r'\badicionar evento\b', caseSensitive: false),
    RegExp(r'\bsaldo insuficiente\b', caseSensitive: false),
    RegExp(r'\bsaldo na loja\b', caseSensitive: false),
    RegExp(r'\bsaldo inicial de teste\b', caseSensitive: false),
    RegExp(r'\bclique (?:em|no|na|para|aqui)\b', caseSensitive: false),
    RegExp(r'\btoque (?:em|no|na|para)\b', caseSensitive: false),
    RegExp(r'\bverifique (?:sua|seu|o|a)\b', caseSensitive: false),
    RegExp(r'\binforme (?:sua|seu|o|a|um|uma)\b', caseSensitive: false),
    RegExp(r'\bda disciplina\b', caseSensitive: false),
    RegExp(r'\bde disciplina\b', caseSensitive: false),
    RegExp(r'\bpor disciplina\b', caseSensitive: false),
    RegExp(r'\bnova disciplina\b', caseSensitive: false),
    RegExp(r'\b(?:sua|esta|nova|da|na) conta\b', caseSensitive: false),
    RegExp(r'\b(?:no|do|seu) perfil\b', caseSensitive: false),
    RegExp(r'\b(?:entrar|fazer) login\b', caseSensitive: false),
    RegExp(r'\b(?:enviar|reenviar) (?:um )?e-mail\b', caseSensitive: false),
    RegExp(
      r'\be-mail (?:atualizado|verificado|enviado|cadastrado)\b',
      caseSensitive: false,
    ),
    RegExp(r'\benviamos um\b', caseSensitive: false),
    RegExp(r'\bfoi enviado\b', caseSensitive: false),
    RegExp(
      r'\b(?:sua|nova)\s+foto de perfil\b|\bfoto de perfil\s+(?:atualizada|salva|removida)\b',
      caseSensitive: false,
    ),
    RegExp(r'\bcadernos? de estudos?\b', caseSensitive: false),
    RegExp(r'\bgrupos? de estudo\b', caseSensitive: false),
    RegExp(r'\bbloco de (?:estudo|foco)\b', caseSensitive: false),
    RegExp(r'\bsess[ãa]o de foco\b', caseSensitive: false),
    RegExp(r'\b(?:em|no) calend[áa]rio\b', caseSensitive: false),
    RegExp(r'\b(?:de estudo|de estudos|de revis[ãa]o|de simulado)\b', caseSensitive: false),
    RegExp(r'\bbanco de dados\b', caseSensitive: false),
    RegExp(r'\bdo grupo\b', caseSensitive: false),
    RegExp(r'\bnova aba\b', caseSensitive: false),
    RegExp(r'\bconversas salvas\b', caseSensitive: false),
    RegExp(
      r'\bconversas?\s+(?:salvas?|recentes?|com|do|da|no|na|noesis)\b',
      caseSensitive: false,
    ),
    RegExp(r'\btempo restante\b', caseSensitive: false),
    RegExp(r'\bconta (?:aster|local|desvinculada|vinculada)\b', caseSensitive: false),
    RegExp(r'\bno grupo\b', caseSensitive: false),
    RegExp(r'\bna carteira\b', caseSensitive: false),
    RegExp(r'\bpor (?:card|quest[ãa]o)\b', caseSensitive: false),
    RegExp(r'\bp/\s*revisar\b', caseSensitive: false),
    RegExp(r'\btemas e idioma\b', caseSensitive: false),
    RegExp(r'\btimer e metas\b', caseSensitive: false),
    RegExp(r'\bnova\s+categoria\b|\bnovo\s+bloco\b', caseSensitive: false),
    RegExp(r'\bmédia\s*(?::|\{?\w*\}?\s*%)', caseSensitive: false),
  ];

  static final RegExp _portugueseSuffixPattern = RegExp(
    r'(?<![\p{L}\p{N}_])(?:'
    r'[\p{L}]*(?:ção|ções|ões|sões|xão|xões|ável|áveis|ível|íveis|'
    r'ância|âncias|ência|ências|ança|anças|ença|enças|'
    r'ário|ária|ários|árias|ório|ória|órios|órias|ício|ícia|ícios|ícias)'
    r'|[\p{L}]+(?:ão|ãos|ães)'
    r'|[\p{L}]{2,}(?:são|idade)'
    r')(?![\p{L}\p{N}_])',
    caseSensitive: false,
    unicode: true,
  );

  static final RegExp _portugueseWordPattern = RegExp(
    r'(?<![\p{L}\p{N}_])(?:'
    r'não|você|vocês|amanhã|hoje|ontem|agora|também|então|estão|serão|através|além|mês|bônus|'
    r'é|já|até|às|têm|contém|mantém|obtém|ainda|após|depois|enquanto|tudo|quem|quais|'
    r'nosso|nossa|nossos|nossas|seu|seus|suas|nenhum|nenhuma|nenhuns|nenhumas|dias|'
    r'simulado|simulados|caderno|cadernos|trilha|trilhas|desempenho|calendário|diário|diária|'
    r'configurações|notificações|anotações|conquistas|baralho|baralhos|revisão|revisões|'
    r'sessão|versão|conexão|conclusão|concluído|concluída|concluídos|concluídas|'
    r'segurança|faísca|névoa|fechar|excluir|excluído|excluída|excluídos|excluídas|'
    r'voltar|carregando|aguarde|aguardando|parabéns|obrigado|obrigada|'
    r'bem-vindo|bem-vinda|boas-vindas|acessar|acesso|acesse|contas|geral|'
    r'questão|questões|pergunta|perguntas|resposta|respostas|assunto|assuntos|'
    r'nível|níveis|turma|turmas|loja|lojas|identidade|acerto|acertos|acertou|erro|erros|errado|errada|'
    r'opção|opções|tarefa|tarefas|estudante|estudantes|estudar|estudo|estudos|estudado|estudadas|'
    r'feito|feita|feitos|feitas|sucesso|novamente|dispensar|comunidade|comunidades|'
    r'protetor|protetores|chave|chaves|caixa|atualizado|atualizada|atualizados|atualizadas|'
    r'atualizar|atualizando|privilégio|privilégios|arquivo|arquivos|'
    r'ferramenta|ferramentas|dica|dicas|mensagem|mensagens|resumo|resumos|detalhes|'
    r'conteúdo|conteúdos|cronômetro|cartão|botão|padrão|provedor|provedores|membros|'
    r'estratégia|prévia|selo|selos|senha|senhas|início|salvar|entrar|sair|'
    r'criar|adicionar|alterar|digite|digitar|escolha|escolher|selecione|'
    r'ativar|ativado|ativada|desativar|desativado|desativada|'
    r'compartilhar|compartilhado|compartilhada|compartilhados|acompanhar|acompanhe|'
    r'avançar|avançando|pendentes|fáceis|difíceis|terça|lembrar|trocar|'
    r'atingir|alcançar|alcançado|manter|obter|preencher|anexar|anexado|anexada|anexados|anexadas|'
    r'baixar|limpar|testar|testando|gerar|gerado|gerada|geradores|receber|recebeu|removido|removida|'
    r'redefinir|redefinida|apoiar|apoiador|apoiadores|assinante|assinantes|grátis|'
    r'acurácia|reproduzir|bater|zerar|fixar|mensal|mensalmente|'
    r'credenciais|ecossistema|convite|convidar|criptografia|atalho|atalhos|'
    r'painel|rotina|rotinas|aprendizado|aprendizados|itens|provas|'
    r'semanais|mensais|principais|atuais|gerais|locais|oficiais|adicionais|totais|finais|'
    r'moldura|molduras|desenvolvimento|conhecimento|acompanhamento|agendamento|gerenciamento|preenchimento|'
    r'segunda-feira|terça-feira|quarta-feira|quinta-feira|sexta-feira|'
    r'japão|alemanha|frança|itália|holanda|rússia|indonésia|vietnã|'
    r'direito|direitos|bloco|melhor|gabarito|análise|análises|leitura|'
    r'escuro|escura|esgotado|esgotada|esgotados|esgotadas|falha|falhas|'
    r'estudou|qualquer|selecionar|seletor|brasileiro|brasileira|'
    r'estatística|estatísticas|pilha|errei|nesta|neste|ganho|ganhos|'
    r'dúvida|dúvidas|saída|saídas|matéria|matérias|domínio|domínios|'
    r'áudio|âmbar|rebaixamento|raciocínio|banca|bancas|'
    r'acadêmico|acadêmica|saúde|ícone|ícones|inglês|japonês|alemão|'
    r'francês|espanhol|mandarim'
    r')(?![\p{L}\p{N}_])',
    caseSensitive: false,
    unicode: true,
  );

  /// Returns `true` when [text] contains distinctive Portuguese UI wording
  /// without false-positiving on French (`Français`), Vietnamese (`đã`), or Spanish cognates.
  static bool containsPortugueseLeakage(String text) {
    if (text.trim().isEmpty) return false;
    for (final pattern in _portuguesePhrasePatterns) {
      if (pattern.hasMatch(text)) return true;
    }
    if (_portugueseSuffixPattern.hasMatch(text)) return true;
    if (_portugueseWordPattern.hasMatch(text)) return true;
    return false;
  }

  /// Scans Dart [source] for untranslated Portuguese UI string literals,
  /// skipping comments, `import`/`part`/`export` lines, `.tr(...)` lookup keys,
  /// widget `Key`s, URLs, asset paths, and `debugPrint` calls.
  static List<String> findPortugueseUiMarkers(String source) {
    return _DartUiStringScanner(source).scan();
  }

  static bool _isIdentifierChar(int codeUnit) {
    return (codeUnit >= 48 && codeUnit <= 57) ||
        (codeUnit >= 65 && codeUnit <= 90) ||
        (codeUnit >= 97 && codeUnit <= 122) ||
        codeUnit == 95 ||
        codeUnit == 36;
  }

  static bool _shouldSkipStringLiteral({
    required String value,
    required String linePrefix,
    required String codeBeforeLiteral,
  }) {
    if (value.trim().isEmpty) return true;

    // Skip import / part / export directives
    if (linePrefix.startsWith('import ') ||
        linePrefix.startsWith('part ') ||
        linePrefix.startsWith('export ')) {
      return true;
    }

    // Skip URLs, package URIs, and asset paths
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('package:') ||
        trimmed.startsWith('assets/') ||
        trimmed.startsWith('exemplos_simulados/')) {
      return true;
    }

    // Strip trailing whitespace from preceding code to inspect call sites
    final before = codeBeforeLiteral.trimRight();

    // Skip localization lookup keys (`context.tr(...)`, `NoesisL10n.tr(...)`, `L10n.tr(...)`, `trContext(context, ...)`)
    if (RegExp(r'(?:^|[^\w$])tr\(\s*(?:""\s*)*$').hasMatch(before) ||
        RegExp(r'trContext\(\s*[^,]+,\s*(?:""\s*)*$').hasMatch(before)) {
      return true;
    }

    // Skip widget Keys, RegExp patterns, and debugPrint diagnostics
    if (RegExp(r'(?:^|[^\w$])(?:Value)?Key\(\s*(?:""\s*)*$').hasMatch(before) ||
        RegExp(r'(?:^|[^\w$])RegExp\(\s*(?:""\s*)*$').hasMatch(before) ||
        RegExp(r'(?:^|[^\w$])debugPrint\(\s*(?:""\s*)*$').hasMatch(before)) {
      return true;
    }

    return false;
  }

  static String _stripSimpleInterpolations(String raw) {
    return raw.replaceAll(RegExp(r'(?<!\\)\$[A-Za-z_][A-Za-z0-9_]*'), ' ');
  }
}

class _DartUiStringScanner {
  _DartUiStringScanner(this.source) : len = source.length;

  final String source;
  final int len;
  final List<String> markers = <String>[];

  int i = 0;
  int line = 1;
  int lineStartOffset = 0;

  static final RegExp _debugPrintPrefixPattern = RegExp(
    r'(?:^|[^\w$])debugPrint\s*$',
  );

  List<String> scan() {
    _scanCode(stopOnClosingBrace: false, inheritedDebugPrintDepth: 0);
    return markers;
  }

  static String _codeTail(StringBuffer codeBuffer) {
    final text = codeBuffer.toString();
    if (text.length <= 512) return text;
    final tail = text.substring(text.length - 512);
    codeBuffer
      ..clear()
      ..write(tail);
    return tail;
  }

  void _scanCode({
    required bool stopOnClosingBrace,
    required int inheritedDebugPrintDepth,
  }) {
    final codeBuffer = StringBuffer();
    var braceDepth = stopOnClosingBrace ? 1 : 0;
    var debugPrintParenDepth = inheritedDebugPrintDepth;

    while (i < len) {
      final ch = source[i];

      if (ch == '\n') {
        codeBuffer.write('\n');
        if (codeBuffer.length > 1024) {
          _codeTail(codeBuffer);
        }
        line++;
        i++;
        lineStartOffset = i;
        continue;
      }

      if (stopOnClosingBrace) {
        if (ch == '{') {
          braceDepth++;
          codeBuffer.write('{');
          i++;
          continue;
        }
        if (ch == '}') {
          braceDepth--;
          i++;
          if (braceDepth == 0) {
            return;
          }
          codeBuffer.write('}');
          continue;
        }
      }

      // Skip single-line comments `// ...`
      if (ch == '/' && i + 1 < len && source[i + 1] == '/') {
        while (i < len && source[i] != '\n') {
          i++;
        }
        continue;
      }

      // Skip block comments `/* ... */` (supporting Dart nesting)
      if (ch == '/' && i + 1 < len && source[i + 1] == '*') {
        i += 2;
        var depth = 1;
        while (i < len && depth > 0) {
          if (source[i] == '\n') {
            line++;
            i++;
            lineStartOffset = i;
            continue;
          }
          if (source[i] == '/' && i + 1 < len && source[i + 1] == '*') {
            depth++;
            i += 2;
            continue;
          }
          if (source[i] == '*' && i + 1 < len && source[i + 1] == '/') {
            depth--;
            i += 2;
            continue;
          }
          i++;
        }
        codeBuffer.write(' ');
        continue;
      }

      if (ch == '(') {
        if (debugPrintParenDepth > 0) {
          debugPrintParenDepth++;
        } else if (_debugPrintPrefixPattern.hasMatch(_codeTail(codeBuffer))) {
          debugPrintParenDepth = 1;
        }
        codeBuffer.write('(');
        i++;
        continue;
      }

      if (ch == ')') {
        if (debugPrintParenDepth > 0) {
          debugPrintParenDepth--;
        }
        codeBuffer.write(')');
        i++;
        continue;
      }

      // Check raw string prefix `r'...'` / `r"..."` or standard string literal
      final isRaw =
          ch == 'r' &&
          i + 1 < len &&
          (source[i + 1] == "'" || source[i + 1] == '"') &&
          (i == 0 ||
              !LocalizationTestHelpers._isIdentifierChar(
                source.codeUnitAt(i - 1),
              ));

      if (isRaw || ch == "'" || ch == '"') {
        _scanStringLiteral(
          isRaw: isRaw,
          codeBuffer: codeBuffer,
          debugPrintParenDepth: debugPrintParenDepth,
        );
        codeBuffer.write(' "" ');
        continue;
      }

      codeBuffer.write(ch);
      i++;
    }
  }

  void _scanStringLiteral({
    required bool isRaw,
    required StringBuffer codeBuffer,
    required int debugPrintParenDepth,
  }) {
    final startLine = line;
    final currentLinePrefix = source.substring(lineStartOffset, i).trimLeft();
    final prefixContext = _codeTail(codeBuffer);

    final quoteOffset = isRaw ? i + 1 : i;
    final quote = source[quoteOffset];
    final isTriple =
        quoteOffset + 2 < len &&
        source[quoteOffset + 1] == quote &&
        source[quoteOffset + 2] == quote;

    i = quoteOffset + (isTriple ? 3 : 1);
    final outsideInterpolation = StringBuffer();

    final skipByContext =
        debugPrintParenDepth > 0 ||
        LocalizationTestHelpers._shouldSkipStringLiteral(
          value: '__NON_EMPTY__',
          linePrefix: currentLinePrefix,
          codeBeforeLiteral: prefixContext,
        );

    while (i < len) {
      final c = source[i];
      if (c == '\n') {
        line++;
        lineStartOffset = i + 1;
        outsideInterpolation.write('\n');
        i++;
        continue;
      }

      if (!isRaw && c == r'\' && i + 1 < len) {
        final next = source[i + 1];
        if (next == '\n') {
          line++;
          lineStartOffset = i + 2;
        }
        outsideInterpolation.write(c);
        outsideInterpolation.write(next);
        i += 2;
        continue;
      }

      if (!isRaw && c == r'$' && i + 1 < len && source[i + 1] == '{') {
        i += 2;
        outsideInterpolation.write(' ');
        _scanCode(
          stopOnClosingBrace: true,
          inheritedDebugPrintDepth: skipByContext ? 1 : debugPrintParenDepth,
        );
        continue;
      }

      if (isTriple) {
        if (i + 2 < len &&
            source[i] == quote &&
            source[i + 1] == quote &&
            source[i + 2] == quote) {
          i += 3;
          break;
        }
      } else if (c == quote) {
        i++;
        break;
      }

      outsideInterpolation.write(c);
      i++;
    }

    if (skipByContext) return;

    final rawOutside = outsideInterpolation.toString();
    if (LocalizationTestHelpers._shouldSkipStringLiteral(
      value: rawOutside,
      linePrefix: currentLinePrefix,
      codeBeforeLiteral: prefixContext,
    )) {
      return;
    }

    final cleaned = LocalizationTestHelpers._stripSimpleInterpolations(
      rawOutside,
    );
    if (LocalizationTestHelpers.containsPortugueseLeakage(cleaned)) {
      final compact = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
      final preview = compact.length > 80
          ? '${compact.substring(0, 77)}...'
          : compact;
      markers.add('L$startLine: $preview');
    }
  }
}
