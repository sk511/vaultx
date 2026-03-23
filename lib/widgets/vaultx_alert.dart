import 'package:flutter/material.dart';
import '../services/vault_provider.dart';
import '../utils/theme.dart';

// ─── VaultX Alert Dialog ──────────────────────────────────────────────────────
class VaultXAlert extends StatelessWidget {
  final String title, message;
  final AlertType type;
  final VoidCallback onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  const VaultXAlert({
    super.key,
    required this.title,
    required this.message,
    required this.type,
    required this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = switch (type) {
      AlertType.success => (icon: Icons.check_circle_rounded,  color: FColors.emerald, bg: FColors.emeraldDim),
      AlertType.error   => (icon: Icons.cancel_rounded,         color: FColors.red,     bg: FColors.redDim),
      AlertType.warning => (icon: Icons.warning_rounded,        color: FColors.amber,   bg: FColors.amberDim),
      AlertType.info    => (icon: Icons.info_rounded,           color: FColors.blue,    bg: FColors.blueDim),
    };

    return Dialog(
      backgroundColor: FColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: cfg.bg, borderRadius: BorderRadius.circular(18)),
            child: Icon(cfg.icon, color: cfg.color, size: 34),
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(
              color: FColors.text, fontWeight: FontWeight.w700,
              fontSize: 18, letterSpacing: -0.3),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(
              color: FColors.textMuted, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          // Optional action button (e.g. "Open Settings")
          if (actionLabel != null && onAction != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final action = onAction; // capture before dismiss nulls it
                  onDismiss();
                  action?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: cfg.color,
                  foregroundColor: type == AlertType.success ? FColors.emeraldDk : FColors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  minimumSize: const Size(0, 48),
                ),
                child: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onDismiss,
              style: TextButton.styleFrom(
                backgroundColor: FColors.surfaceAlt,
                foregroundColor: FColors.textMuted,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                minimumSize: const Size(0, 48),
              ),
              child: Text(actionLabel != null ? 'DISMISS' : 'GOT IT',
                  style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Biometric Overlay ────────────────────────────────────────────────────────
class BiometricOverlay extends StatelessWidget {
  final String biometricLabel;
  const BiometricOverlay({super.key, required this.biometricLabel});

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black.withOpacity(0.94),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(alignment: Alignment.center, children: [
        Container(
          width: 96, height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: FColors.emerald.withOpacity(0.22), width: 2),
          ),
        ),
        const SizedBox(width: 96, height: 96,
            child: CircularProgressIndicator(color: FColors.emerald, strokeWidth: 2)),
        const Icon(Icons.shield_outlined, size: 44, color: FColors.emerald),
      ]),
      const SizedBox(height: 24),
      const Text('Identity Check', style: TextStyle(
          color: FColors.text, fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(
        biometricLabel == 'Face ID'
            ? 'Look at your device to continue'
            : biometricLabel == 'Fingerprint'
                ? 'Place your finger on the sensor'
                : 'Verify your identity to continue',
        style: const TextStyle(color: FColors.textMuted, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    ])),
  );
}
