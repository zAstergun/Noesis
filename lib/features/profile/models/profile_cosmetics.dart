import 'package:flutter/material.dart';
import '../../../core/localization/noesis_l10n.dart';

enum ProfileCosmeticCategory {
  banner,
  frame,
  title,
}

class ProfileCosmeticItem {
  const ProfileCosmeticItem({
    required this.id,
    required this.category,
    required this.name,
    required this.subtitle,
    required this.price,
    this.isVipOnly = false,
    this.gradientColors = const [],
    this.accentColor = const Color(0xFF7B6EF6),
    this.icon = Icons.auto_awesome_rounded,
  });

  final String id;
  final ProfileCosmeticCategory category;
  final String name;
  final String subtitle;
  final int price;
  final bool isVipOnly;
  final List<Color> gradientColors;
  final Color accentColor;
  final IconData icon;

  bool get isFree => price <= 0 && !isVipOnly;
  String get localizedName => NoesisL10n.tr(name);
  String get localizedSubtitle => NoesisL10n.tr(subtitle);
}

/// Catálogo de Capas, Molduras e Títulos do Perfil (compráveis na Loja com Insights ou exclusivos VIP).
class ProfileCosmeticsCatalog {
  ProfileCosmeticsCatalog._();

  static const String defaultBannerId = 'banner_default';
  static const String defaultFrameId = 'frame_default';
  static const String defaultTitleId = 'title_none';

  static List<ProfileCosmeticItem> get banners => [
    ProfileCosmeticItem(
      id: defaultBannerId,
      category: ProfileCosmeticCategory.banner,
      name: NoesisL10n.tr('Névoa do Elo'),
      subtitle: NoesisL10n.tr('Degradê suave automático do seu Elo atual'),
      price: 0,
      accentColor: const Color(0xFF7B6EF6),
      icon: Icons.gradient_rounded,
    ),
    ProfileCosmeticItem(
      id: 'banner_lavender_aurora',
      category: ProfileCosmeticCategory.banner,
      name: NoesisL10n.tr('Aurora Lavanda'),
      subtitle: NoesisL10n.tr('Violeta profundo com reflexo índigo suave'),
      price: 220,
      gradientColors: const [Color(0xFF7C3AED), Color(0xFF6366F1), Color(0xFF38BDF8)],
      accentColor: const Color(0xFF7C3AED),
      icon: Icons.nights_stay_rounded,
    ),
    ProfileCosmeticItem(
      id: 'banner_emerald_forest',
      category: ProfileCosmeticCategory.banner,
      name: NoesisL10n.tr('Bosque Esmeralda'),
      subtitle: NoesisL10n.tr('Menta viva com profundidade oceânica'),
      price: 320,
      gradientColors: const [Color(0xFF10B981), Color(0xFF0EA5E9)],
      accentColor: const Color(0xFF10B981),
      icon: Icons.eco_rounded,
    ),
    ProfileCosmeticItem(
      id: 'banner_ocean_deep',
      category: ProfileCosmeticCategory.banner,
      name: NoesisL10n.tr('Abismo Oceânico'),
      subtitle: NoesisL10n.tr('Azul abissal com brilho ciano sereno'),
      price: 440,
      gradientColors: const [Color(0xFF1D4ED8), Color(0xFF0284C7), Color(0xFF2DD4BF)],
      accentColor: const Color(0xFF0284C7),
      icon: Icons.waves_rounded,
    ),
    ProfileCosmeticItem(
      id: 'banner_solar_amber',
      category: ProfileCosmeticCategory.banner,
      name: NoesisL10n.tr('Crepúsculo Dourado'),
      subtitle: NoesisL10n.tr('Âmbar luminoso com toque coral vibrante'),
      price: 580,
      gradientColors: const [Color(0xFFF59E0B), Color(0xFFF43F5E)],
      accentColor: const Color(0xFFF59E0B),
      icon: Icons.wb_sunny_rounded,
    ),
    ProfileCosmeticItem(
      id: 'banner_sakura_mist',
      category: ProfileCosmeticCategory.banner,
      name: NoesisL10n.tr('Horizonte Sakura'),
      subtitle: NoesisL10n.tr('Pétala rosada com transição ametista'),
      price: 720,
      gradientColors: const [Color(0xFFEC4899), Color(0xFFA855F7)],
      accentColor: const Color(0xFFEC4899),
      icon: Icons.local_florist_rounded,
    ),
    ProfileCosmeticItem(
      id: 'banner_cosmic_prism',
      category: ProfileCosmeticCategory.banner,
      name: NoesisL10n.tr('Prisma Noesis'),
      subtitle: NoesisL10n.tr('Espectro exclusivo violeta, menta e azul cobalto'),
      price: 950,
      gradientColors: const [Color(0xFF4F46E5), Color(0xFF8B5CF6), Color(0xFF2DD4BF)],
      accentColor: const Color(0xFF6366F1),
      icon: Icons.auto_awesome_rounded,
    ),
    ProfileCosmeticItem(
      id: 'banner_vip_imperial',
      category: ProfileCosmeticCategory.banner,
      name: NoesisL10n.tr('Manto Imperial VIP'),
      subtitle: NoesisL10n.tr('Ouro solar real sobre grafite nobre (exclusivo VIP)'),
      price: 0,
      isVipOnly: true,
      gradientColors: const [Color(0xFF1E1B4B), Color(0xFFD97706), Color(0xFFFBBF24)],
      accentColor: const Color(0xFFD97706),
      icon: Icons.workspace_premium_rounded,
    ),
    ProfileCosmeticItem(
      id: 'banner_vip_nebula',
      category: ProfileCosmeticCategory.banner,
      name: NoesisL10n.tr('Nebulosa Astral VIP'),
      subtitle: NoesisL10n.tr('Horizonte sideral índigo e turquesa (exclusivo VIP)'),
      price: 0,
      isVipOnly: true,
      gradientColors: const [Color(0xFF312E81), Color(0xFF9333EA), Color(0xFF06B6D4)],
      accentColor: const Color(0xFF9333EA),
      icon: Icons.nights_stay_rounded,
    ),
    ProfileCosmeticItem(
      id: 'banner_vip_crimson',
      category: ProfileCosmeticCategory.banner,
      name: NoesisL10n.tr('Veludo Rubi VIP'),
      subtitle: NoesisL10n.tr('Borgonha profundo com brilho âmbar (exclusivo VIP)'),
      price: 0,
      isVipOnly: true,
      gradientColors: const [Color(0xFF881337), Color(0xFFE11D48), Color(0xFFF59E0B)],
      accentColor: const Color(0xFFE11D48),
      icon: Icons.diamond_rounded,
    ),
  ];

  static List<ProfileCosmeticItem> get frames => [
    ProfileCosmeticItem(
      id: defaultFrameId,
      category: ProfileCosmeticCategory.frame,
      name: NoesisL10n.tr('Borda Limpa'),
      subtitle: NoesisL10n.tr('Contorno clássico minimalista'),
      price: 0,
      accentColor: const Color(0xFF94A3B8),
      icon: Icons.circle_outlined,
    ),
    ProfileCosmeticItem(
      id: 'frame_lavender',
      category: ProfileCosmeticCategory.frame,
      name: NoesisL10n.tr('Halo Lavanda'),
      subtitle: NoesisL10n.tr('Anel brilhante em lavanda e violeta'),
      price: 180,
      gradientColors: const [Color(0xFF8B5CF6), Color(0xFF6366F1)],
      accentColor: const Color(0xFF7C3AED),
      icon: Icons.blur_circular_rounded,
    ),
    ProfileCosmeticItem(
      id: 'frame_mint',
      category: ProfileCosmeticCategory.frame,
      name: NoesisL10n.tr('Pulso Menta'),
      subtitle: NoesisL10n.tr('Aura em verde esmeralda e turquesa'),
      price: 280,
      gradientColors: const [Color(0xFF3DD598), Color(0xFF06B6D4)],
      accentColor: const Color(0xFF10B981),
      icon: Icons.radar_rounded,
    ),
    ProfileCosmeticItem(
      id: 'frame_sapphire',
      category: ProfileCosmeticCategory.frame,
      name: NoesisL10n.tr('Anel Safira'),
      subtitle: NoesisL10n.tr('Borda cobalto cristalina de alta nitidez'),
      price: 400,
      gradientColors: const [Color(0xFF2563EB), Color(0xFF38BDF8)],
      accentColor: const Color(0xFF2563EB),
      icon: Icons.lens_blur_rounded,
    ),
    ProfileCosmeticItem(
      id: 'frame_gold',
      category: ProfileCosmeticCategory.frame,
      name: NoesisL10n.tr('Coroa Solar'),
      subtitle: NoesisL10n.tr('Moldura dourada de alta intensidade'),
      price: 560,
      gradientColors: const [Color(0xFFFBBF24), Color(0xFFF97316)],
      accentColor: const Color(0xFFD97706),
      icon: Icons.wb_incandescent_rounded,
    ),
    ProfileCosmeticItem(
      id: 'frame_prism',
      category: ProfileCosmeticCategory.frame,
      name: NoesisL10n.tr('Prisma Cósmico'),
      subtitle: NoesisL10n.tr('Contorno multicolorido Noesis'),
      price: 820,
      gradientColors: const [Color(0xFF6366F1), Color(0xFF3DD598), Color(0xFFF59E0B)],
      accentColor: const Color(0xFF6366F1),
      icon: Icons.flare_rounded,
    ),
    ProfileCosmeticItem(
      id: 'frame_vip_crown',
      category: ProfileCosmeticCategory.frame,
      name: NoesisL10n.tr('Auréola Real VIP'),
      subtitle: NoesisL10n.tr('Ouro puro luminoso (exclusivo VIP)'),
      price: 0,
      isVipOnly: true,
      gradientColors: const [Color(0xFFFDE047), Color(0xFFD97706), Color(0xFFF59E0B)],
      accentColor: const Color(0xFFD97706),
      icon: Icons.workspace_premium_rounded,
    ),
    ProfileCosmeticItem(
      id: 'frame_vip_astral',
      category: ProfileCosmeticCategory.frame,
      name: NoesisL10n.tr('Órbita Astral VIP'),
      subtitle: NoesisL10n.tr('Arco estelar violeta e turquesa (exclusivo VIP)'),
      price: 0,
      isVipOnly: true,
      gradientColors: const [Color(0xFF9333EA), Color(0xFF2DD4BF), Color(0xFF38BDF8)],
      accentColor: const Color(0xFF9333EA),
      icon: Icons.auto_awesome_rounded,
    ),
    ProfileCosmeticItem(
      id: 'frame_vip_obsidian',
      category: ProfileCosmeticCategory.frame,
      name: NoesisL10n.tr('Diamante Rubi VIP'),
      subtitle: NoesisL10n.tr('Borda carmesim com reflexo dourado (exclusivo VIP)'),
      price: 0,
      isVipOnly: true,
      gradientColors: const [Color(0xFFE11D48), Color(0xFFFBBF24)],
      accentColor: const Color(0xFFE11D48),
      icon: Icons.diamond_rounded,
    ),
  ];

  static List<ProfileCosmeticItem> get titles => [
    ProfileCosmeticItem(
      id: defaultTitleId,
      category: ProfileCosmeticCategory.title,
      name: NoesisL10n.tr('Sem título'),
      subtitle: NoesisL10n.tr('Exibir apenas nome, @ e Elo'),
      price: 0,
      accentColor: const Color(0xFF94A3B8),
      icon: Icons.horizontal_rule_rounded,
    ),
    ProfileCosmeticItem(
      id: 'title_curious',
      category: ProfileCosmeticCategory.title,
      name: NoesisL10n.tr('Mente Inquieta'),
      subtitle: NoesisL10n.tr('Insígnia de exploração contínua'),
      price: 200,
      accentColor: const Color(0xFF0EA5E9),
      icon: Icons.psychology_alt_rounded,
    ),
    ProfileCosmeticItem(
      id: 'title_strategist',
      category: ProfileCosmeticCategory.title,
      name: NoesisL10n.tr('Estrategista'),
      subtitle: NoesisL10n.tr('Foco em consistência e revisão espaçada'),
      price: 300,
      accentColor: const Color(0xFF10B981),
      icon: Icons.route_rounded,
    ),
    ProfileCosmeticItem(
      id: 'title_polymath',
      category: ProfileCosmeticCategory.title,
      name: NoesisL10n.tr('Polímata'),
      subtitle: NoesisL10n.tr('Domínio versátil em múltiplas disciplinas'),
      price: 420,
      accentColor: const Color(0xFFEC4899),
      icon: Icons.hub_rounded,
    ),
    ProfileCosmeticItem(
      id: 'title_architect',
      category: ProfileCosmeticCategory.title,
      name: NoesisL10n.tr('Arquiteto do Saber'),
      subtitle: NoesisL10n.tr('Construção sólida entre teoria e prática'),
      price: 580,
      accentColor: const Color(0xFF8B5CF6),
      icon: Icons.architecture_rounded,
    ),
    ProfileCosmeticItem(
      id: 'title_sentinel',
      category: ProfileCosmeticCategory.title,
      name: NoesisL10n.tr('Guardião da Ofensiva'),
      subtitle: NoesisL10n.tr('Disciplina diária inabalável nos estudos'),
      price: 740,
      accentColor: const Color(0xFFF97316),
      icon: Icons.local_fire_department_rounded,
    ),
    ProfileCosmeticItem(
      id: 'title_sage',
      category: ProfileCosmeticCategory.title,
      name: NoesisL10n.tr('Mestre Noesis'),
      subtitle: NoesisL10n.tr('Distinção máxima comprável de perfil estudantil'),
      price: 920,
      accentColor: const Color(0xFF6366F1),
      icon: Icons.school_rounded,
    ),
    ProfileCosmeticItem(
      id: 'title_vip_patron',
      category: ProfileCosmeticCategory.title,
      name: NoesisL10n.tr('Mecenas VIP'),
      subtitle: NoesisL10n.tr('Apoiador oficial do ecossistema Noesis (exclusivo VIP)'),
      price: 0,
      isVipOnly: true,
      accentColor: const Color(0xFFD97706),
      icon: Icons.workspace_premium_rounded,
    ),
    ProfileCosmeticItem(
      id: 'title_vip_luminary',
      category: ProfileCosmeticCategory.title,
      name: NoesisL10n.tr('Luminar VIP'),
      subtitle: NoesisL10n.tr('Destaque brilhante em rankings e grupos (exclusivo VIP)'),
      price: 0,
      isVipOnly: true,
      accentColor: const Color(0xFF9333EA),
      icon: Icons.auto_awesome_rounded,
    ),
    ProfileCosmeticItem(
      id: 'title_vip_sovereign',
      category: ProfileCosmeticCategory.title,
      name: NoesisL10n.tr('Soberano Noético VIP'),
      subtitle: NoesisL10n.tr('Insígnia lendária dourada exclusiva (exclusivo VIP)'),
      price: 0,
      isVipOnly: true,
      accentColor: const Color(0xFFE11D48),
      icon: Icons.diamond_rounded,
    ),
  ];

  static List<ProfileCosmeticItem> get all => [
        ...banners,
        ...frames,
        ...titles,
      ];

  static List<ProfileCosmeticItem> byCategory(ProfileCosmeticCategory category) {
    switch (category) {
      case ProfileCosmeticCategory.banner:
        return banners;
      case ProfileCosmeticCategory.frame:
        return frames;
      case ProfileCosmeticCategory.title:
        return titles;
    }
  }

  static ProfileCosmeticItem? findById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }

  static ProfileCosmeticItem? equippedTitleFor(String? titleId) {
    if (titleId == null || titleId.isEmpty || titleId == defaultTitleId) return null;
    final found = findById(titleId);
    if (found == null || found.category != ProfileCosmeticCategory.title) return null;
    return found;
  }

  static ProfileCosmeticItem? equippedFrameFor(String? frameId) {
    if (frameId == null || frameId.isEmpty || frameId == defaultFrameId) return null;
    final found = findById(frameId);
    if (found == null || found.category != ProfileCosmeticCategory.frame) return null;
    return found;
  }

  static ProfileCosmeticItem? equippedBannerFor(String? bannerId) {
    if (bannerId == null || bannerId.isEmpty || bannerId == defaultBannerId) return null;
    final found = findById(bannerId);
    if (found == null || found.category != ProfileCosmeticCategory.banner) return null;
    return found;
  }
}
