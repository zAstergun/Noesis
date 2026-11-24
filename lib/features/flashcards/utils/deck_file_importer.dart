import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:es_compression/zstd.dart';
import 'package:flutter/foundation.dart';
import '../models/flashcard_model.dart';

class DeckFileContent {
  final String fileName;
  final int fileSizeBytes;
  final String rawText;
  final String suggestedTitle;
  final String suggestedSubject;
  final bool isAnkiFormat;
  final List<Flashcard> parsedCards;

  DeckFileContent({
    required this.fileName,
    required this.fileSizeBytes,
    required this.rawText,
    required this.suggestedTitle,
    required this.suggestedSubject,
    required this.isAnkiFormat,
    required this.parsedCards,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class DeckFileImporter {
  /// Decodifica e processa arquivos do Anki (.apkg, .colpkg, .txt, .tsv, .csv), Markdown (.md) e Texto (.txt)
  static DeckFileContent parse(String fileName, List<int> bytes) {
    final dotIndex = fileName.lastIndexOf('.');
    final ext = dotIndex != -1 ? fileName.substring(dotIndex).toLowerCase() : '';
    final nameWithoutExt = dotIndex != -1 ? fileName.substring(0, dotIndex) : fileName;
    final baseName = nameWithoutExt.replaceAll(RegExp(r'[_.\-]'), ' ').trim();
    final defaultTitle = _formatTitle(baseName);

    // 1. Verificar se é pacote compactado Anki (.apkg / .colpkg) ou arquivo ZIP
    final isZipMagic = bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;

    if (ext == '.apkg' || ext == '.colpkg' || ext == '.zip' || isZipMagic) {
      try {
        final apkgResult = _extractFromAnkiPackage(fileName, bytes, defaultTitle);
        if (apkgResult != null) {
          return apkgResult;
        }
      } catch (_) {
        // Se falhar a descompactação como APKG, tenta fallback para texto
      }
    }

    // 2. Processar como texto puro (Anki TSV/TXT exportado, Markdown ou Texto)
    String text = '';
    try {
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      text = String.fromCharCodes(bytes);
    }

    final suggestedTitle = defaultTitle.isNotEmpty ? defaultTitle : 'Novo Baralho';
    final suggestedSubject = _inferSubject(suggestedTitle, text);

    final List<Flashcard> detectedCards = [];
    bool isAnki = false;

    // Verificar se é formato Anki exportado em texto (tab-separated com ou sem cabeçalhos)
    final lines = text.split(RegExp(r'\r?\n'));
    final contentLines = lines.where((l) => l.trim().isNotEmpty && !l.trim().startsWith('#')).toList();

    int tabCount = 0;
    for (final l in contentLines.take(20)) {
      if (l.contains('\t')) tabCount++;
    }

    if (tabCount >= 2 || text.contains('#separator:tab')) {
      isAnki = true;
      for (int i = 0; i < contentLines.length; i++) {
        final line = contentLines[i];
        final parts = line.split('\t');
        if (parts.length >= 2) {
          final front = _cleanHtml(parts[0].trim());
          final back = _cleanHtml(parts[1].trim());
          final rawTags = parts.length >= 3
              ? parts[2].trim().split(RegExp(r'\s+')).where((t) {
                  final lower = t.toLowerCase();
                  return t.isNotEmpty &&
                      !t.startsWith('[sound:') &&
                      !t.endsWith(']') &&
                      !lower.endsWith('.mp3') &&
                      !lower.endsWith('.ogg') &&
                      !lower.endsWith('.wav');
                }).toList()
              : <String>[];
          final tags = rawTags.isNotEmpty ? rawTags : [suggestedSubject];

          if (front.isNotEmpty && back.isNotEmpty) {
            detectedCards.add(Flashcard(
              id: 'anki-$i-${DateTime.now().millisecondsSinceEpoch}',
              front: front,
              back: back,
              tags: tags,
            ));
          }
        }
      }
    }

    // Se for Markdown, verificar se tem padrão de Q&A (ex: "Q: ... A: ..." ou "## Pergunta \n Resposta")
    if (!isAnki && ext == '.md') {
      final qaPattern = RegExp(
        r'(?:Q:|Pergunta:|Frente:)\s*(.+?)\s*(?:A:|Resposta:|Verso:)\s*(.+?)(?=(?:Q:|Pergunta:|Frente:)|$)',
        caseSensitive: false,
        dotAll: true,
      );
      final matches = qaPattern.allMatches(text);
      if (matches.length >= 2) {
        int idx = 0;
        for (final m in matches) {
          final f = m.group(1)?.trim() ?? '';
          final b = m.group(2)?.trim() ?? '';
          if (f.isNotEmpty && b.isNotEmpty) {
            detectedCards.add(Flashcard(
              id: 'md-$idx-${DateTime.now().millisecondsSinceEpoch}',
              front: f,
              back: b,
              tags: [suggestedSubject],
            ));
            idx++;
          }
        }
        if (detectedCards.isNotEmpty) isAnki = true;
      }
    }

    return DeckFileContent(
      fileName: fileName,
      fileSizeBytes: bytes.length,
      rawText: text,
      suggestedTitle: suggestedTitle.isNotEmpty ? suggestedTitle : 'Novo Baralho Importado',
      suggestedSubject: suggestedSubject,
      isAnkiFormat: isAnki && detectedCards.isNotEmpty,
      parsedCards: detectedCards,
    );
  }

  // --------------------------------------------------------------------------
  // PARSER DE PACOTE ANKI (.apkg / .colpkg) COM SUPORTE A ANKI MODERNO E ÁUDIO
  // --------------------------------------------------------------------------
  static DeckFileContent? _extractFromAnkiPackage(String fileName, List<int> bytes, String defaultTitle) {
    final archive = ZipDecoder().decodeBytes(bytes);
    if (archive.isEmpty) return null;

    // 1. Ler o mapa de mídias (áudios/imagens) do Anki
    final mediaMap = <String, String>{};
    for (final file in archive.files) {
      if (file.name == 'media') {
        try {
          final mediaJson = utf8.decode(file.content, allowMalformed: true);
          final dynamic decoded = jsonDecode(mediaJson);
          if (decoded is Map) {
            decoded.forEach((key, val) {
              if (val is String) {
                final fn = val.trim();
                mediaMap[fn] = key.toString();
                mediaMap[fn.toLowerCase()] = key.toString();
              }
            });
          }
        } catch (_) {}
        break;
      }
    }

    final archiveFilesByName = <String, ArchiveFile>{};
    for (final f in archive.files) {
      archiveFilesByName[f.name] = f;
    }

    // Extrator de Data URI de áudio com base no nome do arquivo no pacote Anki
    String? extractAudioDataUri(String rawFieldText) {
      String? soundFileName;
      final match = RegExp(r'\[sound:([^\]]+)\]', caseSensitive: false).firstMatch(rawFieldText);
      if (match != null) {
        soundFileName = match.group(1)?.trim();
      } else {
        // Detecta referências diretas de arquivos de áudio (.mp3, .ogg, .wav, .m4a)
        final directMatch = RegExp(r'([^\x00-\x1F\\/:\*\?"<>|]+\.(?:mp3|ogg|wav|m4a))', caseSensitive: false).firstMatch(rawFieldText);
        if (directMatch != null) {
          soundFileName = directMatch.group(1)?.trim();
        }
      }
      if (soundFileName == null || soundFileName.isEmpty) return null;

      final entryKey = mediaMap[soundFileName] ?? mediaMap[soundFileName.toLowerCase()];
      if (entryKey == null) return null;

      final mediaFile = archiveFilesByName[entryKey];
      if (mediaFile != null && mediaFile.content.isNotEmpty) {
        final ext = soundFileName.toLowerCase();
        final mime = ext.endsWith('.ogg')
            ? 'audio/ogg'
            : (ext.endsWith('.wav') ? 'audio/wav' : 'audio/mp3');
        return 'data:$mime;base64,${base64Encode(mediaFile.content)}';
      }
      return null;
    }

    // 2. Prioridade de bases de dados do Anki:
    // collection.anki21b (zstd) -> collection.anki21 -> collection.anki2
    final candidateNames = ['collection.anki21b', 'collection.anki21', 'collection.anki2'];
    List<Flashcard> cards = [];
    String detectedTitle = defaultTitle;

    for (final name in candidateNames) {
      final dbFile = archiveFilesByName[name];
      if (dbFile == null) continue;

      final rawBytes = dbFile.content;
      if (rawBytes.isEmpty) continue;

      final dbBytes = _prepareSqliteBytes(rawBytes);
      if (dbBytes.length < 16) continue;

      // Tentar extrair o nome real do baralho da tabela 'col'
      try {
        final textPreview = utf8.decode(dbBytes, allowMalformed: true);
        final deckMatches = RegExp(r'"name":\s*"([^"]+)"').allMatches(textPreview);
        for (final m in deckMatches) {
          final n = m.group(1);
          if (n != null &&
              n != 'Default' &&
              n != 'Padrão' &&
              !n.startsWith('Default::') &&
              !n.startsWith('Padrão::')) {
            detectedTitle = _cleanHtml(n.replaceAll('::', ' - ')).trim();
            break;
          }
        }
      } catch (_) {}

      // Estratégia A: SQLite Leaf B-Tree walker
      cards = _parseSqliteAnkiCards(dbBytes, extractAudioDataUri);

      // Estratégia B: Scanner de delimitador 0x1F
      if (cards.isEmpty) {
        cards = _scanFallbackAnkiCards(dbBytes, extractAudioDataUri);
      }

      // Remover quaisquer cartões que sejam apenas o aviso stub de versão antiga
      cards.removeWhere((c) =>
          c.front.contains('This file requires a newer version of Anki') ||
          c.back.contains('This file requires a newer version of Anki'));

      if (cards.isNotEmpty) {
        break; // Sucesso ao extrair da base correta
      }
    }

    // Se não encontrou no SQLite, verifica se há arquivos de texto/markdown dentro do ZIP
    if (cards.isEmpty) {
      for (final file in archive.files) {
        final fName = file.name.toLowerCase();
        if (fName.endsWith('.txt') || fName.endsWith('.tsv') || fName.endsWith('.md') || fName.endsWith('.csv')) {
          final contentBytes = file.content;
          if (contentBytes.isNotEmpty) {
            return parse(file.name, contentBytes);
          }
        }
      }
      return null;
    }

    final suggestedTitle = detectedTitle.isNotEmpty ? detectedTitle : 'Baralho Anki';
    final sampleContent = cards.take(15).map((c) => '${c.front} ${c.back}').join(' ');
    final suggestedSubject = _inferSubject(suggestedTitle, sampleContent);

    final buffer = StringBuffer();
    buffer.writeln('Baralho Anki: $suggestedTitle');
    buffer.writeln('Total de cartões identificados: ${cards.length}');
    buffer.writeln('Disciplina inferida: $suggestedSubject\n');
    buffer.writeln('Amostra de Flashcards do Baralho:');
    for (int i = 0; i < cards.length && i < 30; i++) {
      buffer.writeln('P: ${cards[i].front}');
      buffer.writeln('R: ${cards[i].back}\n');
    }

    return DeckFileContent(
      fileName: fileName,
      fileSizeBytes: bytes.length,
      rawText: buffer.toString().trim(),
      suggestedTitle: suggestedTitle,
      suggestedSubject: suggestedSubject,
      isAnkiFormat: cards.isNotEmpty,
      parsedCards: cards,
    );
  }

  /// Descomprime Zstandard se o arquivo começar com a assinatura mágica do Zstd (0x28 0xB5 0x2F 0xFD)
  static List<int> _prepareSqliteBytes(List<int> rawBytes) {
    if (rawBytes.length >= 4 &&
        rawBytes[0] == 0x28 &&
        rawBytes[1] == 0xB5 &&
        rawBytes[2] == 0x2F &&
        rawBytes[3] == 0xFD) {
      try {
        final decompressed = zstd.decode(rawBytes);
        return decompressed;
      } catch (e) {
        debugPrint('Erro ao descomprimir zstd: $e');
      }
    }
    return rawBytes;
  }

  // --------------------------------------------------------------------------
  // ESTRATÉGIA A: PARSER DE REGISTROS SQLITE (LEAF TABLE B-TREE)
  // --------------------------------------------------------------------------
  static List<Flashcard> _parseSqliteAnkiCards(List<int> dbBytes, [String? Function(String)? audioExtractor]) {
    final List<Flashcard> cards = [];
    final Set<String> seenFronts = {};
    if (dbBytes.length < 100) return cards;

    int pageSize = (dbBytes[16] << 8) | dbBytes[17];
    if (pageSize == 1) pageSize = 65536;
    if (pageSize < 512 || pageSize > 65536) pageSize = 4096;

    final numPages = dbBytes.length ~/ pageSize;

    for (int p = 0; p < numPages; p++) {
      final pageStart = p * pageSize;
      final headerOffset = p == 0 ? 100 : 0;
      if (pageStart + headerOffset + 8 > dbBytes.length) continue;

      // 0x0D = Leaf Table B-Tree page (contém as linhas da tabela notes)
      final pageType = dbBytes[pageStart + headerOffset];
      if (pageType != 0x0D) continue;

      final numCells = (dbBytes[pageStart + headerOffset + 3] << 8) | dbBytes[pageStart + headerOffset + 4];
      for (int c = 0; c < numCells; c++) {
        final ptrOffset = pageStart + headerOffset + 8 + (c * 2);
        if (ptrOffset + 2 > dbBytes.length) continue;

        final cellOffsetInPage = (dbBytes[ptrOffset] << 8) | dbBytes[ptrOffset + 1];
        final cellStart = pageStart + cellOffsetInPage;
        if (cellStart >= dbBytes.length) continue;

        int curr = cellStart;
        // 1. Ler tamanho do payload
        final payloadSizeV = _readVarint(dbBytes, curr);
        curr += payloadSizeV.bytesRead;

        // 2. Ler RowID
        final rowIdV = _readVarint(dbBytes, curr);
        curr += rowIdV.bytesRead;

        // 3. Início do Payload da Linha
        final payloadStart = curr;
        final headerSizeV = _readVarint(dbBytes, curr);
        curr += headerSizeV.bytesRead;

        final recordHeaderEnd = payloadStart + headerSizeV.value;
        if (recordHeaderEnd > dbBytes.length) continue;

        final List<int> serialTypes = [];
        while (curr < recordHeaderEnd && curr < dbBytes.length) {
          final stV = _readVarint(dbBytes, curr);
          serialTypes.add(stV.value);
          curr += stV.bytesRead;
        }

        // 4. Ler colunas de dados
        int colDataOffset = recordHeaderEnd;
        String? extractedFront;
        String? extractedBack;
        String? extractedAudio;
        String? extractedFrontAudio;
        String? extractedBackAudio;
        List<String> extractedTags = [];

        for (final st in serialTypes) {
          if (st >= 13 && st % 2 == 1) {
            final strLen = (st - 13) ~/ 2;
            if (colDataOffset + strLen <= dbBytes.length) {
              final strBytes = dbBytes.sublist(colDataOffset, colDataOffset + strLen);

              // No Anki, a coluna flds sempre contém o separador 0x1F (\x1f)
              if (strBytes.contains(0x1F)) {
                final text = utf8.decode(strBytes, allowMalformed: true);
                final parts = text.split('\x1f');
                if (parts.length >= 2) {
                  final f = _cleanHtml(parts[0]);
                  final b = _cleanHtml(parts[1]);
                  if (f.isNotEmpty && b.isNotEmpty) {
                    if (!f.contains('This file requires a newer version of Anki') &&
                        !b.contains('This file requires a newer version of Anki')) {
                      extractedFront = f;
                      extractedBack = b;
                      if (audioExtractor != null) {
                        final fAudio = audioExtractor(parts[0]);
                        final bAudio = audioExtractor(parts[1]);
                        extractedAudio = fAudio ?? audioExtractor(text);
                        extractedFrontAudio = fAudio;
                        extractedBackAudio = bAudio;
                      }
                    }
                  }
                }
              } else if (strBytes.length > 2 && extractedFront != null) {
                // Pode ser a coluna de tags
                final tagStr = utf8.decode(strBytes, allowMalformed: true).trim();
                if (tagStr.isNotEmpty && !tagStr.startsWith('{') && !tagStr.startsWith('[')) {
                  extractedTags = tagStr.split(RegExp(r'\s+')).where((t) {
                    final lower = t.toLowerCase();
                    return t.isNotEmpty &&
                        !t.startsWith('[sound:') &&
                        !t.endsWith(']') &&
                        !lower.endsWith('.mp3') &&
                        !lower.endsWith('.ogg') &&
                        !lower.endsWith('.wav');
                  }).toList();
                }
              }
            }
            colDataOffset += strLen;
          } else if (st >= 12 && st % 2 == 0) {
            final blobLen = (st - 12) ~/ 2;
            colDataOffset += blobLen;
          } else if (st == 1) {
            colDataOffset += 1;
          } else if (st == 2) {
            colDataOffset += 2;
          } else if (st == 3) {
            colDataOffset += 3;
          } else if (st == 4) {
            colDataOffset += 4;
          } else if (st == 5) {
            colDataOffset += 6;
          } else if (st == 6 || st == 7) {
            colDataOffset += 8;
          }
        }

        if (extractedFront != null && extractedBack != null && !seenFronts.contains(extractedFront)) {
          seenFronts.add(extractedFront);
          cards.add(Flashcard(
            id: 'anki-sql-${cards.length}-${DateTime.now().millisecondsSinceEpoch}',
            front: extractedFront,
            back: extractedBack,
            tags: extractedTags,
            audioUrl: extractedAudio,
            frontAudioUrl: extractedFrontAudio ?? extractedAudio,
            backAudioUrl: extractedBackAudio,
          ));
        }
      }
    }

    return cards;
  }

  // --------------------------------------------------------------------------
  // ESTRATÉGIA B: SCANNER DE RESISTÊNCIA DE DELIMITADOR DE CAMPOS ANKI (0x1F)
  // --------------------------------------------------------------------------
  static List<Flashcard> _scanFallbackAnkiCards(List<int> bytes, [String? Function(String)? audioExtractor]) {
    final List<Flashcard> cards = [];
    final Set<String> seenFronts = {};

    for (int i = 0; i < bytes.length; i++) {
      if (bytes[i] == 0x1F) {
        // Encontrar início do primeiro campo
        int start = i - 1;
        while (start >= 0 && start >= i - 1500) {
          final b = bytes[start];
          if (b < 0x20 && b != 0x0A && b != 0x0D && b != 0x09) {
            start++;
            break;
          }
          start--;
        }
        if (start < 0) start = 0;

        // Encontrar final do registro inteiro (pode conter múltiplos 0x1F)
        int end = i + 1;
        while (end < bytes.length && end <= i + 3500) {
          final b = bytes[end];
          if (b < 0x20 && b != 0x1F && b != 0x0A && b != 0x0D && b != 0x09) {
            break;
          }
          end++;
        }

        if (i > start && end > i + 1) {
          try {
            final recordRaw = utf8.decode(bytes.sublist(start, end), allowMalformed: true).trim();
            final parts = recordRaw.split('\x1f');
            if (parts.length >= 2) {
              final f = _cleanHtml(parts[0]);
              final b = _cleanHtml(parts[1]);

              if (f.length >= 2 && b.length >= 2 && !seenFronts.contains(f)) {
                if (!f.contains('This file requires a newer version of Anki') &&
                    !b.contains('This file requires a newer version of Anki') &&
                    _isPrintableText(f) && _isPrintableText(b)) {
                  seenFronts.add(f);
                  String? audio;
                  String? frontAudio;
                  String? backAudio;
                  if (audioExtractor != null) {
                    final parts = recordRaw.split('\x1f');
                    if (parts.isNotEmpty) frontAudio = audioExtractor(parts[0]);
                    if (parts.length > 1) backAudio = audioExtractor(parts[1]);
                    audio = frontAudio ?? audioExtractor(recordRaw);
                  }
                  cards.add(Flashcard(
                    id: 'anki-scan-${cards.length}-${DateTime.now().millisecondsSinceEpoch}',
                    front: f,
                    back: b,
                    tags: ['Anki Import'],
                    audioUrl: audio,
                    frontAudioUrl: frontAudio ?? audio,
                    backAudioUrl: backAudio,
                  ));
                }
              }
            }
          } catch (_) {}
        }
        // Avançar o cursor para o final deste registro para não re-processar os campos adicionais
        i = end;
      }
    }

    return cards;
  }

  static bool _isPrintableText(String str) {
    if (str.isEmpty || str.length > 3000) return false;
    int printableCount = 0;
    for (int i = 0; i < str.length; i++) {
      final code = str.codeUnitAt(i);
      if (code >= 32 || code == 10 || code == 13 || code == 9) {
        printableCount++;
      }
    }
    return (printableCount / str.length) > 0.85;
  }

  static _VarintResult _readVarint(List<int> bytes, int offset) {
    int value = 0;
    int i = 0;
    while (i < 8 && offset + i < bytes.length) {
      final b = bytes[offset + i];
      value = (value << 7) | (b & 0x7F);
      i++;
      if ((b & 0x80) == 0) {
        return _VarintResult(value, i);
      }
    }
    if (offset + i < bytes.length) {
      final b = bytes[offset + i];
      value = (value << 8) | b;
      i++;
    }
    return _VarintResult(value, i);
  }

  static String _cleanHtml(String str) {
    return str
        // Remover caracteres de controle não-imprimíveis (exceto newline e tab)
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
        // Cloze deletions do Anki: {{c1::Resposta::Dica}} -> Resposta
        .replaceAllMapped(RegExp(r'\{\{c\d+::(.*?)(?:::(.*?))?\}\}'), (m) => m.group(1) ?? '')
        // Limpar referências de áudio do Anki [sound:audio.mp3]
        .replaceAll(RegExp(r'\[sound:[^\]]+\]', caseSensitive: false), '')
        // Tags de quebra de linha e parágrafos
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</?(?:p|div|tr|li)[^>]*>', caseSensitive: false), '\n')
        // Limpar quaisquer outras tags HTML remanescentes
        .replaceAll(RegExp(r'<img[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        // Entidades HTML comuns
        .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'&amp;', caseSensitive: false), '&')
        .replaceAll(RegExp(r'&lt;', caseSensitive: false), '<')
        .replaceAll(RegExp(r'&gt;', caseSensitive: false), '>')
        .replaceAll(RegExp(r'&quot;', caseSensitive: false), '"')
        .replaceAll(RegExp(r'&#39;', caseSensitive: false), "'")
        .replaceAll(RegExp(r'""'), '"')
        // Normalizar múltiplas quebras de linha
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String _formatTitle(String raw) {
    if (raw.isEmpty) return 'Estudos';
    return raw.split(' ').map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  static String _inferSubject(String title, String content) {
    final combined = '$title $content'.toLowerCase();
    if (combined.contains('grammar') ||
        combined.contains('lesson') ||
        combined.contains('inglês') ||
        combined.contains('english') ||
        combined.contains('idioma') ||
        combined.contains('vocab') ||
        combined.contains('français') ||
        combined.contains('espanhol') ||
        combined.contains('alemão') ||
        combined.contains('languages')) {
      return 'Idiomas';
    }
    if (combined.contains('cripto') || combined.contains('pki') || combined.contains('cifra') || combined.contains('aes') || combined.contains('rsa')) {
      return 'Criptografia';
    }
    if (combined.contains('owasp') || combined.contains('segurança') || combined.contains('security') || combined.contains('vulnerab') || combined.contains('firewall')) {
      return 'Segurança';
    }
    if (combined.contains('aws') || combined.contains('cloud') || combined.contains('nuvem') || combined.contains('docker') || combined.contains('kubernetes')) {
      return 'Cloud & DevOps';
    }
    if (combined.contains('rede') || combined.contains('tcp') || combined.contains('dns') || combined.contains('ip') || combined.contains('protocolo')) {
      return 'Redes';
    }
    if (combined.contains('algoritmo') || combined.contains('estrutura') || combined.contains('big-o') || combined.contains('grafo') || combined.contains('árvore')) {
      return 'Algoritmos';
    }
    if (combined.contains('banco') || combined.contains('sql') || combined.contains('postgres') || combined.contains('database')) {
      return 'Banco de Dados';
    }
    if (combined.contains('constitucional') || combined.contains('administrativo') || combined.contains('direito') || combined.contains('artigo') || combined.contains('lei')) {
      return 'Direito';
    }
    if (combined.contains('inglês') || combined.contains('english') || combined.contains('idioma') || combined.contains('vocab')) {
      return 'Idiomas';
    }
    return 'Tecnologia';
  }
}

class _VarintResult {
  final int value;
  final int bytesRead;
  _VarintResult(this.value, this.bytesRead);
}

