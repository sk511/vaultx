import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vault_entry.dart';
import '../services/vault_provider.dart';
import '../utils/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VaultProvider>();
    return GestureDetector(
      onTap: vp.resetActivity,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          // Stats
          FCard(child: Row(children: [
            _Stat(value: '${vp.entries.length}', label: 'ITEMS STORED'),
            _Divider(),
            const _Stat(value: 'MILITARY', label: 'GRADE ENCRYPT', color: FColors.emerald),
            _Divider(),
            const _Stat(value: 'ZERO', label: 'KNOWLEDGE', color: FColors.blue),
          ])),
          const SizedBox(height: 20),

          // No duress indicator — settings looks identical in both real and duress mode.

          // Authentication
          const FSectionLabel('AUTHENTICATION'),
          FCard(child: Column(children: [
            _SettingRow(
              icon: Icons.fingerprint, iconColor: FColors.emerald, iconBg: FColors.emeraldDim,
              title: vp.biometricLabel,
              subtitle: !vp.biometricAvailable
                  ? 'Tap to set up on this device'
                  : vp.config.useBiometrics
                      ? 'Active — required for sensitive actions'
                      : 'Tap to enable for extra security',
              trailing: Switch(value: vp.config.useBiometrics, onChanged: (_) => vp.toggleBiometrics()),
            ),
            const FDivider(),
            _SettingRow(
              icon: Icons.timer_outlined, iconColor: FColors.blue, iconBg: FColors.blueDim,
              title: 'Auto-Lock Timer',
              subtitle: 'Lock after ${_lockLabel(vp.config.autoLockSeconds)} of inactivity',
              trailing: _badge(_lockLabel(vp.config.autoLockSeconds)),
              onTap: () => _showLockPicker(context, vp),
            ),
            const FDivider(),
            _SettingRow(
              icon: Icons.lock_outline, iconColor: FColors.red, iconBg: FColors.redDim,
              title: 'Lock Now', subtitle: 'Immediately secure vault',
              trailing: const Icon(Icons.chevron_right, color: FColors.textDim),
              onTap: vp.lockVault,
            ),
          ])),
          const SizedBox(height: 20),

          // Privacy
          const FSectionLabel('PRIVACY'),
          FCard(child: Column(children: [
            _SettingRow(
              icon: Icons.content_paste_off, iconColor: FColors.amber, iconBg: FColors.amberDim,
              title: 'Clipboard Auto-Clear',
              subtitle: vp.config.clipboardClearSeconds > 0
                  ? 'Clear after ${_clipLabel(vp.config.clipboardClearSeconds)}' : 'Disabled',
              trailing: _badge(_clipLabel(vp.config.clipboardClearSeconds)),
              onTap: () => _showClipPicker(context, vp),
            ),
            const FDivider(),
            _SettingRow(
              icon: Icons.no_photography_outlined, iconColor: FColors.red, iconBg: FColors.redDim,
              title: 'Screenshot Protection',
              subtitle: 'Prevent screenshots & screen recording',
              trailing: Switch(
                value: vp.config.screenshotProtection,
                onChanged: (v) => vp.updateConfig(vp.config.copyWith(screenshotProtection: v)),
              ),
            ),
          ])),
          const SizedBox(height: 20),

          // Advanced Security
          const FSectionLabel('ADVANCED SECURITY'),
          FCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SettingRow(
              icon: Icons.warning_amber_outlined, iconColor: FColors.amber, iconBg: FColors.amberDim,
              title: 'Duress / Dummy Vault',
              subtitle: 'Show a decoy vault under coercion',
              trailing: const Icon(Icons.chevron_right, color: FColors.textDim),
              onTap: () => _showDuressModal(context, vp),
            ),
            const FDivider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _InfoRow(icon: Icons.info_outline, color: FColors.textDim,
                    text: 'Too many wrong password attempts will temporarily lock the app — protecting you from brute-force attacks.'),
                const SizedBox(height: 10),
                _InfoRow(icon: Icons.shield_outlined, color: FColors.emerald,
                    text: 'Your master password never touches our servers. Everything is scrambled on your device before saving.'),
              ]),
            ),
          ])),
          const SizedBox(height: 20),

          // Cloud Sync
          const FSectionLabel('CLOUD SYNC'),
          FCard(child: vp.currentUser != null
              ? Column(children: [
                  _SettingRow(
                    icon: Icons.person_outline, iconColor: FColors.blue, iconBg: FColors.blueDim,
                    title: 'Signed In', subtitle: vp.currentUser!.email ?? 'Google Account',
                  ),
                  const FDivider(),
                  _SettingRow(
                    icon: Icons.cloud_upload_outlined, iconColor: FColors.emerald, iconBg: FColors.emeraldDim,
                    title: 'Sync to Cloud',
                    subtitle: 'Back up your vault — merges with existing cloud data',
                    trailing: vp.syncStatus == SyncStatus.syncing
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: FColors.emerald))
                        : vp.syncStatus == SyncStatus.success
                            ? const Icon(Icons.check_circle, color: FColors.emerald, size: 18)
                            : const Icon(Icons.chevron_right, color: FColors.textDim),
                    onTap: vp.syncStatus == SyncStatus.syncing ? null : vp.syncToCloud,
                  ),
                  const FDivider(),
                  _SettingRow(
                    icon: Icons.cloud_download_outlined, iconColor: FColors.blue, iconBg: FColors.blueDim,
                    title: 'Restore from Cloud',
                    subtitle: 'Merge cloud backup into your current vault',
                    trailing: const Icon(Icons.chevron_right, color: FColors.textDim),
                    onTap: () => _showRestoreDialog(context, vp),
                  ),
                  const FDivider(),
                  GestureDetector(
                    onTap: () => showDialog(context: context, builder: (_) => _ConfirmDialog(
                      title: 'Sign Out',
                      message: 'Sign out of cloud sync? Your local vault stays encrypted.',
                      onConfirm: vp.signOut,
                    )),
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: FColors.redDim, borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: FColors.red.withOpacity(0.2)),
                      ),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.logout_outlined, size: 15, color: FColors.red),
                        SizedBox(width: 8),
                        Text('SIGN OUT', style: TextStyle(color: FColors.red,
                            fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1)),
                      ]),
                    ),
                  ),
                ])
              : const Padding(
                  padding: EdgeInsets.all(16),
                  child: _InfoRow(icon: Icons.cloud_off_outlined, color: FColors.textDim,
                      text: 'Sign in on the lock screen to back up your vault to the cloud. Backups are fully encrypted before upload — only you can read them.'),
                )),
          const SizedBox(height: 20),

          // Security trust card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: FColors.emerald.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: FColors.emerald.withOpacity(0.15)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.verified_user_rounded, size: 16, color: FColors.emerald),
                SizedBox(width: 8),
                Text('WHY YOUR DATA IS SAFE', style: TextStyle(color: FColors.emerald,
                    fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
              ]),
              const SizedBox(height: 14),
              ...[
                (Icons.lock_rounded,            'Your master password never leaves this device — ever'),
                (Icons.shield_rounded,           'Every item is scrambled before being saved, even locally'),
                (Icons.cloud_done_rounded,       'Cloud backups are pre-encrypted — your provider can\'t read them'),
                (Icons.phonelink_lock_rounded,   'Stored in your phone\'s secure hardware chip, not plain storage'),
                (Icons.fingerprint,              'Biometric verification required for every sensitive action'),
                (Icons.timer_rounded,            'Vault locks automatically when you stop using it'),
                (Icons.visibility_off_rounded,   'Screenshots and screen recording are blocked system-wide'),
                (Icons.sync_lock_rounded,        'Data breach scanner checks passwords without revealing them'),
                (Icons.qr_code_scanner_rounded,  'Built-in 2FA code generator — no separate app needed'),
                (Icons.block_rounded,            'Too many wrong attempts? Vault locks itself for your protection'),
              ].map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(item.$1, size: 15, color: FColors.emerald),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item.$2, style: const TextStyle(
                      color: FColors.textMuted, fontSize: 13, height: 1.4))),
                ]),
              )),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Label helpers ────────────────────────────────────────────────────────────
  String _lockLabel(int s) {
    if (s == 30)  return '30 seconds';
    if (s == 60)  return '1 minute';
    if (s == 120) return '2 minutes';
    if (s == 300) return '5 minutes';
    return '${s}s';
  }

  String _clipLabel(int s) {
    if (s == 0)  return 'Never';
    if (s == 15) return '15 seconds';
    if (s == 30) return '30 seconds';
    if (s == 60) return '1 minute';
    return '${s}s';
  }

  Widget _badge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: FColors.surface, borderRadius: BorderRadius.circular(6),
        border: Border.all(color: FColors.border)),
    child: Text(label, style: const TextStyle(color: FColors.textDim,
        fontSize: 11, fontWeight: FontWeight.w700)),
  );

  // ── Pickers ──────────────────────────────────────────────────────────────────
  void _showLockPicker(BuildContext context, VaultProvider vp) =>
      _showOptionPicker(context, 'Auto-Lock Timer',
        options: const [(30,'30 seconds'),(60,'1 minute'),(120,'2 minutes'),(300,'5 minutes')],
        current: vp.config.autoLockSeconds,
        onSelect: (v) => vp.updateConfig(vp.config.copyWith(autoLockSeconds: v)));

  void _showClipPicker(BuildContext context, VaultProvider vp) =>
      _showOptionPicker(context, 'Clipboard Auto-Clear',
        options: const [(15,'15 seconds'),(30,'30 seconds'),(60,'1 minute'),(0,'Never')],
        current: vp.config.clipboardClearSeconds,
        onSelect: (v) => vp.updateConfig(vp.config.copyWith(clipboardClearSeconds: v)));

  void _showOptionPicker(BuildContext context, String title,
      {required List<(int,String)> options, required int current,
       required ValueChanged<int> onSelect}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(
              color: FColors.textDim, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(title, style: FText.title()),
          const SizedBox(height: 8),
          ...options.map((t) => ListTile(
            title: Text(t.$2, style: TextStyle(
                color: t.$1 == current ? FColors.emerald : FColors.text)),
            trailing: t.$1 == current
                ? const Icon(Icons.check_circle, color: FColors.emerald) : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: t.$1 == current ? FColors.emeraldDim : Colors.transparent,
            onTap: () { onSelect(t.$1); Navigator.pop(context); },
          )),
        ]),
      ),
    );
  }

  // ── Duress vault modal ────────────────────────────────────────────────────────
  void _showDuressModal(BuildContext context, VaultProvider vp) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: FColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _DuressModalContent(vp: vp),
    );
  }

  // ── Restore from cloud modal ──────────────────────────────────────────────────
  void _showRestoreDialog(BuildContext context, VaultProvider vp) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: FColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _RestoreModalContent(vp: vp),
    );
  }
}

// ─── Duress modal (StatefulWidget so it can manage its own state) ─────────────
class _DuressModalContent extends StatefulWidget {
  final VaultProvider vp;
  const _DuressModalContent({required this.vp});
  @override
  State<_DuressModalContent> createState() => _DuressModalContentState();
}

class _DuressModalContentState extends State<_DuressModalContent> {
  final _ctrl = TextEditingController();
  bool _show  = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 32),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: FColors.textDim, borderRadius: BorderRadius.circular(2)))),
      const Row(children: [
        Icon(Icons.warning_amber, color: FColors.amber, size: 18),
        SizedBox(width: 8),
        Text('Setup Duress Vault', style: TextStyle(
            color: FColors.text, fontWeight: FontWeight.w700, fontSize: 17)),
      ]),
      const SizedBox(height: 12),
      const Text(
        'When this password is entered at login, an empty decoy vault is shown instead '
        'of your real data. Cloud sync fakes success in duress mode.',
        style: TextStyle(color: FColors.textMuted, fontSize: 13, height: 1.5)),
      const SizedBox(height: 16),
      TextField(
        controller: _ctrl, obscureText: !_show,
        style: const TextStyle(color: FColors.text),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Enter unique duress password',
          suffixIcon: IconButton(
            icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: FColors.textDim),
            onPressed: () => setState(() => _show = !_show),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(foregroundColor: FColors.textMuted,
              side: const BorderSide(color: FColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size(0, 48)),
          child: const Text('CANCEL'),
        )),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(
          onPressed: _ctrl.text.isEmpty ? null : () async {
            Navigator.pop(context);
            await widget.vp.createDuressVault(_ctrl.text);
          },
          style: ElevatedButton.styleFrom(backgroundColor: FColors.amber,
              foregroundColor: const Color(0xFF451A03),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size(0, 48)),
          child: const Text('CREATE DUMMY'),
        )),
      ]),
    ]),
  );
}

// ─── Restore modal (StatefulWidget) ──────────────────────────────────────────
class _RestoreModalContent extends StatefulWidget {
  final VaultProvider vp;
  const _RestoreModalContent({required this.vp});
  @override
  State<_RestoreModalContent> createState() => _RestoreModalContentState();
}

class _RestoreModalContentState extends State<_RestoreModalContent> {
  final _ctrl = TextEditingController();
  bool _show  = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 32),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: FColors.textDim, borderRadius: BorderRadius.circular(2)))),
      const Row(children: [
        Icon(Icons.cloud_download_outlined, color: FColors.blue, size: 18),
        SizedBox(width: 8),
        Text('Restore from Cloud', style: TextStyle(
            color: FColors.text, fontWeight: FontWeight.w700, fontSize: 17)),
      ]),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: FColors.blueDim,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: FColors.blue.withOpacity(0.2))),
        child: const Text(
          'Your cloud backup will be merged with your local vault. '
          'If the same entry exists in both, the most recently updated version is kept. '
          'No data is ever deleted.',
          style: TextStyle(color: FColors.blue, fontSize: 12, height: 1.5)),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _ctrl, obscureText: !_show,
        style: const TextStyle(color: FColors.text),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Enter your master password',
          suffixIcon: IconButton(
            icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: FColors.textDim),
            onPressed: () => setState(() => _show = !_show),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(foregroundColor: FColors.textMuted,
              side: const BorderSide(color: FColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size(0, 48)),
          child: const Text('CANCEL'),
        )),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(
          onPressed: _ctrl.text.isEmpty ? null : () async {
            Navigator.pop(context);
            await widget.vp.restoreFromCloud(_ctrl.text);
          },
          style: ElevatedButton.styleFrom(backgroundColor: FColors.blue,
              foregroundColor: FColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size(0, 48)),
          child: const Text('RESTORE & MERGE'),
        )),
      ]),
    ]),
  );
}

// ─── Shared helpers ───────────────────────────────────────────────────────────
class _Stat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _Stat({required this.value, required this.label, this.color = FColors.text});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800,
        fontSize: 15, letterSpacing: -0.5)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: FColors.textDim, fontSize: 9,
        fontWeight: FontWeight.w700, letterSpacing: 1.5)),
  ]));
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: FColors.border);
}

class _SettingRow extends StatelessWidget {
  final IconData icon; final Color iconColor, iconBg;
  final String title; final String? subtitle;
  final Widget? trailing; final VoidCallback? onTap;
  const _SettingRow({required this.icon, required this.iconColor, required this.iconBg,
      required this.title, this.subtitle, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(width: 42, height: 42,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: iconColor, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: FColors.text,
              fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.3)),
          if (subtitle != null)
            Text(subtitle!, style: const TextStyle(color: FColors.textMuted, fontSize: 11), maxLines: 2),
        ])),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ]),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final Color color; final String text;
  const _InfoRow({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, size: 15, color: color), const SizedBox(width: 8),
    Expanded(child: Text(text, style: const TextStyle(
        color: FColors.textMuted, fontSize: 11, height: 1.5))),
  ]);
}

class _ConfirmDialog extends StatelessWidget {
  final String title, message; final VoidCallback onConfirm;
  const _ConfirmDialog({required this.title, required this.message, required this.onConfirm});
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: FColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text(title, style: const TextStyle(color: FColors.text)),
    content: Text(message, style: const TextStyle(color: FColors.textMuted)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: FColors.textMuted))),
      TextButton(onPressed: () { Navigator.pop(context); onConfirm(); },
          child: const Text('Confirm', style: TextStyle(color: FColors.red))),
    ],
  );
}
