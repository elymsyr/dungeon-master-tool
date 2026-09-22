import 'package:flutter/material.dart';

/// Dar ekranda etiketini düşürüp yalnız simge kalan eylem düğmesi.
///
/// Hub'ın satırlarında (Yükle + Kopyala + Aktar + Sil) dört etiket mobilde
/// yan yana sığmıyor. 480 dp altında etiket [Tooltip]'e iner, düğme simge
/// genişliğine çeker; geniş ekranda `*.icon` kurucusuyla eskisi gibi davranır.
///
/// Görünüm temadan geliyor — burada tek sabit değer kırılma noktası.
class CompactableButton extends StatelessWidget {
  const CompactableButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.style,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;

  /// `true` → [FilledButton], `false` → [OutlinedButton].
  final bool filled;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 480) {
      return filled
          ? FilledButton.icon(
              onPressed: onPressed,
              icon: icon,
              label: Text(label),
              style: style,
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: icon,
              label: Text(label),
              style: style,
            );
    }
    // Asgari boy Material'ın varsayılanında (64×40) bırakılıyor: temanın
    // dikey dolgusu 4 dp, yani serbest bırakılırsa simge kutusu 26 dp'ye
    // iner ve yanındaki "Yükle" düğmesinden alçak kalırdı.
    return Tooltip(
      message: label,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: style,
              child: icon,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: style,
              child: icon,
            ),
    );
  }
}
