import 'package:flutter/material.dart';

/// Design Tokens e Constantes Oficiais do Aster Soft Clay
/// Fonte: Cofre Obsidian (`Design Systems/Aster Soft Clay/Aster Soft Clay.md`)
class AsterConstants {
  // Supabase Configuration (Aster)
  static const String supabaseUrl = 'https://yofvcyarznuvqntgslep.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlvZnZjeWFyem51dnFudGdzbGVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEyNzg2MDIsImV4cCI6MjEwNjg1NDYwMn0.HpYpKPqu8rE28hrmgZvy3Xf6zE50S6mNyZhXaCHeagw';

  // Branding
  static const String appName = 'Noesis';
  static const String appSubtitle = 'Cognitive OS & AI Study Engine';

  // ─── Paleta de Cores Oficial: Aster Soft Clay ───
  // Fundo ambiente suave (Nevoa)
  static const Color bgNevoa = Color(0xFFEEF0F8);
  static const Color bgCanvas = Color(0xFFEEF0F8);

  // Superfícies de Cartão (White pura elevada)
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF3F4FB);
  static const Color surfaceInset = Color(0xFFE6E8F3);

  // Quatro Pilares Semânticos Oficiais
  static const Color lavanda = Color(0xFF7C6CF0); // Estudo, foco, timer, botão primário
  static const Color menta = Color(0xFF3CCF9A);   // Revisão, constância, sucesso, heatmap
  static const Color ambar = Color(0xFFF5A623);   // Labs, simulados RAG, metas
  static const Color coral = Color(0xFFFF7A90);   // Provas oficiais, prazos, alertas

  // Tipografia de Alto Contraste & Muted
  static const Color textDark = Color(0xFF23233A);   // Títulos, numerais, leitura profunda (Light)
  static const Color textMuted = Color(0xFF6F7190);  // Metadados, subtítulos
  static const Color textFaint = Color(0xFFA7A9C2);  // Bordas e ícones passivos

  // ─── Paleta Oficial Dark Mode: Aster Soft Clay Escuro ───
  static const Color bgDark = Color(0xFF11121C);          // Névoa Noturna profunda grafite/índigo
  static const Color surfaceCardDark = Color(0xFF1B1C2A); // Cartões elevados soft clay
  static const Color surfaceAltDark = Color(0xFF24263A);  // Chips, inputs e superfícies secundárias
  static const Color surfaceInsetDark = Color(0xFF2E3149);// Trilhas, divisores e bordas sutis
  static const Color textLight = Color(0xFFF4F5FB);        // Títulos e leitura em alto contraste (Dark)
  static const Color textMutedDark = Color(0xFF989BB8);    // Subtítulos e metadados no escuro
  static const Color textFaintDark = Color(0xFF656888);    // Bordas e ícones passivos no escuro

  // Compatibilidade com código legado
  static const Color primary = lavanda;
  static const Color secondary = menta;
  static const Color accentRose = coral;
  static const Color accentOrange = ambar;
  static const Color accentAmber = ambar;
  static const Color surfaceDark = surfaceAltDark;
  static const Color cardDark = surfaceCardDark;
  static const Color cardHover = surfaceAltDark;
  static const Color borderDark = Colors.transparent;
  static const Color textDim = textMutedDark;

  // ─── Raios de Curvatura (Clay Radii) ───
  static const double radiusLarge = 28.0;
  static const double radiusMedium = 16.0;
  static const double radiusPill = 999.0;

  // ─── Sombras Multicamadas Soft Clay (Otimizadas para 60/120 FPS no CanvasKit/WebGL) ───
  static const List<BoxShadow> clayShadow = [
    BoxShadow(
      color: Color.fromRGBO(60, 60, 120, 0.08),
      blurRadius: 18,
      offset: Offset(0, 8),
      spreadRadius: -4,
    ),
    BoxShadow(
      color: Color.fromRGBO(60, 60, 120, 0.03),
      blurRadius: 6,
      offset: Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> claySubtleShadow = [
    BoxShadow(
      color: Color.fromRGBO(60, 60, 120, 0.05),
      blurRadius: 8,
      offset: Offset(0, 3),
      spreadRadius: -2,
    ),
  ];

  static const List<BoxShadow> clayListShadow = [
    BoxShadow(
      color: Color.fromRGBO(60, 60, 120, 0.07),
      blurRadius: 10,
      offset: Offset(0, 4),
      spreadRadius: -2,
    ),
  ];

  // ─── Sombras Multicamadas Soft Clay para Dark Mode ───
  static const List<BoxShadow> clayDarkShadow = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.35),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> clayListDarkShadow = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.32),
      blurRadius: 10,
      offset: Offset(0, 4),
      spreadRadius: -2,
    ),
  ];

  static const List<BoxShadow> claySubtleDarkShadow = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.25),
      blurRadius: 8,
      offset: Offset(0, 3),
      spreadRadius: -2,
    ),
  ];

  static const List<BoxShadow> primaryButtonShadow = [
    BoxShadow(
      color: Color.fromRGBO(124, 108, 240, 0.35),
      blurRadius: 12,
      offset: Offset(0, 5),
      spreadRadius: -2,
    ),
  ];
}
