import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../core/localization/noesis_l10n.dart';
import '../core/supabase_service.dart';
import '../core/theme.dart';
import 'vip_privileges.dart';

/// Painel retangular de espectro 2D (Saturação × Brilho) + barra Arco-Íris (Matiz) +
/// entradas editáveis R/G/B e HEX + presets `TONS VIP`, no estilo StudioOS.
class VipRgbSpectrumPicker extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onChanged;
  final double spectrumHeight;
  final bool darkSurface;

  const VipRgbSpectrumPicker({
    super.key,
    required this.color,
    required this.onChanged,
    this.spectrumHeight = 160,
    this.darkSurface = false,
  });

  static String colorToHex(Color c, {bool includeHash = true}) {
    final r = (c.r * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final hex = '$r$g$b'.toUpperCase();
    return includeHash ? '#$hex' : hex;
  }

  static const List<Color> vipTonePresets = [
    Color(0xFFF5B73B), // Ouro VIP
    Color(0xFF00E5FF), // Ciano elétrico
    Color(0xFF9D6BFF), // Lavanda Aster
    Color(0xFFFF5E7E), // Coral vibrante
    Color(0xFF3DD598), // Menta Aster
    Color(0xFFFFFFFF), // Branco puro
    Color(0xFF141418), // Obsidiana
  ];

  @override
  State<VipRgbSpectrumPicker> createState() => _VipRgbSpectrumPickerState();
}

class _VipRgbSpectrumPickerState extends State<VipRgbSpectrumPicker> {
  late HSVColor _hsv;
  late final TextEditingController _rCtrl;
  late final TextEditingController _gCtrl;
  late final TextEditingController _bCtrl;
  late final TextEditingController _hexCtrl;
  bool _isDraggingHsv = false;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.color);
    _rCtrl = TextEditingController();
    _gCtrl = TextEditingController();
    _bCtrl = TextEditingController();
    _hexCtrl = TextEditingController();
    _syncControllersFromColor(widget.color);
  }

  @override
  void didUpdateWidget(covariant VipRgbSpectrumPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color.toARGB32() != widget.color.toARGB32()) {
      if (!_isDraggingHsv) {
        _hsv = HSVColor.fromColor(widget.color);
      }
      _syncControllersFromColor(widget.color);
    }
  }

  @override
  void dispose() {
    _rCtrl.dispose();
    _gCtrl.dispose();
    _bCtrl.dispose();
    _hexCtrl.dispose();
    super.dispose();
  }

  void _syncControllersFromColor(Color c) {
    final r = (c.r * 255.0).round().clamp(0, 255).toString();
    final g = (c.g * 255.0).round().clamp(0, 255).toString();
    final b = (c.b * 255.0).round().clamp(0, 255).toString();
    final hex = VipRgbSpectrumPicker.colorToHex(c);

    if (_rCtrl.text != r) _rCtrl.text = r;
    if (_gCtrl.text != g) _gCtrl.text = g;
    if (_bCtrl.text != b) _bCtrl.text = b;
    if (_hexCtrl.text.toUpperCase() != hex) _hexCtrl.text = hex;
  }

  void _emitHsv(HSVColor next) {
    _isDraggingHsv = true;
    setState(() => _hsv = next);
    final nextColor = next.toColor();
    _syncControllersFromColor(nextColor);
    widget.onChanged(nextColor);
    _isDraggingHsv = false;
  }

  void _updateFromChannel({String? rRaw, String? gRaw, String? bRaw}) {
    final cur = widget.color;
    final nr = (rRaw != null ? int.tryParse(rRaw.trim()) : null) ??
        (cur.r * 255.0).round();
    final ng = (gRaw != null ? int.tryParse(gRaw.trim()) : null) ??
        (cur.g * 255.0).round();
    final nb = (bRaw != null ? int.tryParse(bRaw.trim()) : null) ??
        (cur.b * 255.0).round();
    final nextColor = Color.fromARGB(
      255,
      nr.clamp(0, 255),
      ng.clamp(0, 255),
      nb.clamp(0, 255),
    );
    _hsv = HSVColor.fromColor(nextColor);
    final hex = VipRgbSpectrumPicker.colorToHex(nextColor);
    if (_hexCtrl.text.toUpperCase() != hex) _hexCtrl.text = hex;
    widget.onChanged(nextColor);
  }

  void _applyHex(String raw) {
    final clean = raw.replaceAll('#', '').trim().toUpperCase();
    if (clean.length == 6 && RegExp(r'^[0-9A-F]{6}$').hasMatch(clean)) {
      final nextColor = Color(0xFF000000 | int.parse(clean, radix: 16));
      _hsv = HSVColor.fromColor(nextColor);
      _syncControllersFromColor(nextColor);
      widget.onChanged(nextColor);
    }
  }

  void _pickPreset(Color preset) {
    _hsv = HSVColor.fromColor(preset);
    _syncControllersFromColor(preset);
    widget.onChanged(preset);
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color;
    final hueColor = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();
    final isDarkBg = widget.darkSurface || Theme.of(context).brightness == Brightness.dark;
    final panelBg = widget.darkSurface ? const Color(0xFF151822) : AsterTheme.surfaceAlt(context);
    final boxBg = widget.darkSurface ? const Color(0xFF10131C) : AsterTheme.card(context);
    final boxBorder = widget.darkSurface
        ? Colors.white.withValues(alpha: 0.12)
        : AsterTheme.surfaceInset(context);
    final textCol = widget.darkSurface ? const Color(0xFFF4F5FB) : AsterTheme.text(context);
    final mutedCol = widget.darkSurface ? const Color(0xFF9196B8) : AsterTheme.textMuted(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Painel Retangular 2D (Saturação × Luminosidade)
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.clamp(120.0, 900.0);
            final height = widget.spectrumHeight;
            final thumbX = (_hsv.saturation.clamp(0.0, 1.0) * width).clamp(0.0, width);
            final thumbY = ((1.0 - _hsv.value.clamp(0.0, 1.0)) * height).clamp(0.0, height);

            void handleTouch(Offset local) {
              final s = (local.dx / width).clamp(0.0, 1.0);
              final v = (1.0 - (local.dy / height)).clamp(0.0, 1.0);
              _emitHsv(_hsv.withSaturation(s).withValue(v));
            }

            return GestureDetector(
              key: const Key('vip_rgb_spectrum_canvas'),
              onPanDown: (d) => handleTouch(d.localPosition),
              onPanUpdate: (d) => handleTouch(d.localPosition),
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDarkBg
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.black.withValues(alpha: 0.12),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Colors.white, hueColor],
                          ),
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (thumbX - 10).clamp(2.0, (width - 22).clamp(2.0, width)),
                      top: (thumbY - 10).clamp(2.0, (height - 22).clamp(2.0, height)),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: activeColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // 2. Amostra da cor ativa + Barra de espectro de Matiz (Hue)
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: isDarkBg
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.16),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final barW = constraints.maxWidth.clamp(80.0, 900.0);
                  final thumbLeft = ((_hsv.hue.clamp(0.0, 360.0) / 360.0) * (barW - 18))
                      .clamp(0.0, (barW - 18).clamp(0.0, barW));

                  void updateHue(Offset local) {
                    final nextHue = ((local.dx / barW).clamp(0.0, 1.0) * 360.0)
                        .clamp(0.0, 360.0);
                    _emitHsv(_hsv.withHue(nextHue));
                  }

                  return GestureDetector(
                    key: const Key('vip_rgb_hue_bar'),
                    onPanDown: (d) => updateHue(d.localPosition),
                    onPanUpdate: (d) => updateHue(d.localPosition),
                    child: SizedBox(
                      height: 24,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 14,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF0000),
                                  Color(0xFFFFFF00),
                                  Color(0xFF00FF00),
                                  Color(0xFF00FFFF),
                                  Color(0xFF0000FF),
                                  Color(0xFFFF00FF),
                                  Color(0xFFFF0000),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.14),
                              ),
                            ),
                          ),
                          Positioned(
                            left: thumbLeft,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: hueColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 3. Caixas numéricas editáveis R, G, B + campo HEX
        Row(
          children: [
            Expanded(
              child: _buildChannelBox(
                key: const Key('vip_rgb_r_field'),
                controller: _rCtrl,
                label: 'R',
                labelColor: const Color(0xFFEF4444),
                bg: boxBg,
                border: boxBorder,
                textCol: textCol,
                onChanged: (v) => _updateFromChannel(rRaw: v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildChannelBox(
                key: const Key('vip_rgb_g_field'),
                controller: _gCtrl,
                label: 'G',
                labelColor: const Color(0xFF22C55E),
                bg: boxBg,
                border: boxBorder,
                textCol: textCol,
                onChanged: (v) => _updateFromChannel(gRaw: v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildChannelBox(
                key: const Key('vip_rgb_b_field'),
                controller: _bCtrl,
                label: 'B',
                labelColor: const Color(0xFF3B82F6),
                bg: boxBg,
                border: boxBorder,
                textCol: textCol,
                onChanged: (v) => _updateFromChannel(bRaw: v),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 102,
              child: _buildChannelBox(
                key: const Key('vip_rgb_hex_field'),
                controller: _hexCtrl,
                label: 'HEX',
                labelColor: mutedCol,
                bg: boxBg,
                border: boxBorder,
                textCol: textCol,
                maxLength: 7,
                onChanged: _applyHex,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 4. Barra de presets "TONS VIP"
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: boxBorder),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                context.tr('TONS VIP'),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                  color: mutedCol,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: VipRgbSpectrumPicker.vipTonePresets.map((preset) {
                  final selected = preset.toARGB32() == activeColor.toARGB32();
                  return InkWell(
                    onTap: () => _pickPreset(preset),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: preset,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AsterVipColors.gold
                              : (isDarkBg
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : Colors.black.withValues(alpha: 0.18)),
                          width: selected ? 2.2 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChannelBox({
    required Key key,
    required TextEditingController controller,
    required String label,
    required Color labelColor,
    required Color bg,
    required Color border,
    required Color textCol,
    required ValueChanged<String> onChanged,
    int maxLength = 3,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: key,
            controller: controller,
            maxLength: maxLength,
            textAlign: TextAlign.center,
            onChanged: onChanged,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: textCol,
            ),
            decoration: const InputDecoration(
              counterText: '',
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Abre a janela estilo StudioOS **Seletor RGB VIP** para escolher uma cor personalizada.
Future<Color?> showVipRgbColorPickerDialog(
  BuildContext context, {
  required Color initialColor,
}) {
  return showDialog<Color>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (dialogCtx) {
      Color current = initialColor;
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            key: const Key('vip_rgb_picker_dialog'),
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF11131C),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AsterVipColors.gold.withValues(alpha: 0.42),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AsterVipColors.gold.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: AsterVipColors.gold.withValues(alpha: 0.45),
                              ),
                            ),
                            child: const Center(child: VipCrownIcon(size: 16)),
                          ),
                          const SizedBox(width: 9),
                          Text(
                            context.tr('Seletor RGB VIP'),
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFF4F5FB),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AsterVipColors.gold.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AsterVipColors.gold.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              context.tr('ATIVO'),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AsterVipColors.gold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xFF989BB8),
                            ),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      VipRgbSpectrumPicker(
                        color: current,
                        darkSurface: true,
                        onChanged: (next) => setModalState(() => current = next),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            child: Text(
                              context.tr('Cancelar'),
                              style: GoogleFonts.manrope(
                                color: const Color(0xFFA0A4C4),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            key: const Key('vip_rgb_picker_apply_button'),
                            onPressed: () => Navigator.of(dialogCtx).pop(current),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AsterVipColors.gold,
                              foregroundColor: AsterVipColors.inkBase,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              context.tr('Aplicar Cor'),
                              style: GoogleFonts.manrope(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// Botão circular RGB reutilizável ao lado das paletas do app (Calendário, Cadernos, etc.).
///
/// Para membros VIP, abre o [showVipRgbColorPickerDialog]. Para não-VIP, abre o modal
/// [showVipPrivilegesModal] explicando que a paleta RGB livre é benefício VIP.
class VipRgbColorTrigger extends StatelessWidget {
  final Color currentColor;
  final bool isCustomSelected;
  final ValueChanged<Color> onColorSelected;
  final double size;

  const VipRgbColorTrigger({
    super.key,
    required this.currentColor,
    required this.isCustomSelected,
    required this.onColorSelected,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SupabaseService.isVipNotifier,
      builder: (context, isVip, _) {
        return Tooltip(
          message: isVip
              ? context.tr('Escolher cor personalizada (Seletor RGB VIP)')
              : context.tr('Cores RGB personalizadas (Exclusivo VIP)'),
          child: InkWell(
            key: const Key('vip_rgb_picker_trigger'),
            onTap: () async {
              if (!isVip) {
                await showVipPrivilegesModal(context);
                return;
              }
              final picked = await showVipRgbColorPickerDialog(
                context,
                initialColor: currentColor,
              );
              if (picked != null) {
                onColorSelected(picked);
              }
            },
            borderRadius: BorderRadius.circular(size),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: size,
                  height: size,
                  padding: const EdgeInsets.all(2.4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(
                      colors: [
                        Color(0xFFFF0000),
                        Color(0xFFFFFF00),
                        Color(0xFF00FF00),
                        Color(0xFF00FFFF),
                        Color(0xFF0000FF),
                        Color(0xFFFF00FF),
                        Color(0xFFFF0000),
                      ],
                    ),
                    boxShadow: isCustomSelected
                        ? [
                            BoxShadow(
                              color: currentColor.withValues(alpha: 0.55),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCustomSelected
                          ? currentColor
                          : AsterTheme.card(context),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isCustomSelected
                            ? Icons.check_rounded
                            : Icons.colorize_rounded,
                        size: 15,
                        color: isCustomSelected
                            ? (ThemeData.estimateBrightnessForColor(currentColor) ==
                                    Brightness.light
                                ? const Color(0xFF111111)
                                : Colors.white)
                            : AsterTheme.text(context),
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: -3,
                  end: -3,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF14151E),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AsterVipColors.gold.withValues(alpha: 0.85),
                      ),
                    ),
                    child: const Center(child: VipCrownIcon(size: 8)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Editor VIP de 6 cores RGB/HEX para o tema "Personalizado".
class VipRgbThemeEditor extends StatefulWidget {
  final NoesisCustomThemeColors colors;
  final ValueChanged<NoesisCustomThemeColors> onChanged;
  final VoidCallback onReset;
  final int? selectedSlot;
  final ValueChanged<int>? onSlotSelected;
  final EdgeInsetsGeometry? margin;
  final String? title;

  const VipRgbThemeEditor({
    super.key,
    required this.colors,
    required this.onChanged,
    required this.onReset,
    this.selectedSlot,
    this.onSlotSelected,
    this.margin,
    this.title,
  });

  @override
  State<VipRgbThemeEditor> createState() => _VipRgbThemeEditorState();
}

class _VipRgbThemeEditorState extends State<VipRgbThemeEditor> {
  static List<({String label, String hint})> get _slotMeta => [
        (label: NoesisL10n.tr('1 · Fundo'), hint: NoesisL10n.tr('Cor de fundo geral')),
        (label: NoesisL10n.tr('2 · Cartões'), hint: NoesisL10n.tr('Superfície de cards')),
        (label: NoesisL10n.tr('3 · Primária'), hint: NoesisL10n.tr('Botões e destaques')),
        (label: NoesisL10n.tr('4 · Acento 1'), hint: NoesisL10n.tr('Progresso e revisões')),
        (label: NoesisL10n.tr('5 · Acento 2'), hint: NoesisL10n.tr('Metas e estatísticas')),
        (label: NoesisL10n.tr('6 · Acento 3'), hint: NoesisL10n.tr('Alertas e provas')),
      ];

  late int _selectedSlot;

  Color get _activeColor => widget.colors.asList[_selectedSlot];

  @override
  void initState() {
    super.initState();
    _selectedSlot = (widget.selectedSlot ?? 2).clamp(0, 5);
  }

  @override
  void didUpdateWidget(covariant VipRgbThemeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedSlot != null && widget.selectedSlot != _selectedSlot) {
      _selectedSlot = widget.selectedSlot!.clamp(0, 5);
    }
  }

  void _selectSlot(int index) {
    setState(() => _selectedSlot = index);
    widget.onSlotSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final c = _activeColor;
    final primaryCol = AsterTheme.primary(context);

    return Container(
      key: const Key('vip_custom_theme_editor'),
      margin: widget.margin ?? const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        border: Border.all(
          color: AsterVipColors.gold.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const VipBadgePill(size: VipBadgeSize.sm, interactive: false),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title ?? context.tr('Seletor RGB VIP (6 Cores)'),
                  style: GoogleFonts.manrope(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AsterTheme.text(context),
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('vip_custom_theme_reset_button'),
                onPressed: widget.onReset,
                icon: Icon(Icons.restart_alt_rounded, size: 15, color: AsterTheme.textMuted(context)),
                label: Text(
                  context.tr('Restaurar Padrão'),
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AsterTheme.textMuted(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Seletor dos 6 slots de cor
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(6, (idx) {
              final slotColor = widget.colors.asList[idx];
              final isSelected = _selectedSlot == idx;
              return InkWell(
                key: Key('custom_color_slot_$idx'),
                onTap: () => _selectSlot(idx),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryCol.withValues(alpha: 0.14) : AsterTheme.card(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? primaryCol : AsterTheme.surfaceInset(context),
                      width: isSelected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: slotColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black.withValues(alpha: 0.18)),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        context.tr(_slotMeta[idx].label),
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? primaryCol : AsterTheme.text(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

          // Painel retangular StudioOS + barra arco-íris + caixas R/G/B/HEX + Tons VIP
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AsterTheme.card(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AsterTheme.surfaceInset(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      context.tr(_slotMeta[_selectedSlot].label),
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AsterTheme.text(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr(_slotMeta[_selectedSlot].hint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AsterTheme.textMuted(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                VipRgbSpectrumPicker(
                  color: c,
                  spectrumHeight: 148,
                  onChanged: (nextColor) {
                    widget.onChanged(widget.colors.copyWithSlot(_selectedSlot, nextColor));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
