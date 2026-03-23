import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vault_provider.dart';
import '../utils/theme.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _ctrl   = TextEditingController();
  bool  _showPw = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final vp     = context.watch<VaultProvider>();
    final locked = vp.lockoutSeconds > 0;
    final busy   = vp.isUnlocking || vp.isSigningIn;

    return Scaffold(
      backgroundColor: FColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height
                       - MediaQuery.of(context).padding.top
                       - MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Logo
                Stack(alignment: Alignment.center, children: [
                  Transform.rotate(angle: 0.17, child: Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      color: FColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: FColors.border),
                    ),
                    child: const Icon(Icons.lock, size: 40, color: FColors.emerald),
                  )),
                  Positioned(bottom: 0, right: 0,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: FColors.emerald, shape: BoxShape.circle,
                        border: Border.all(color: FColors.bg, width: 3),
                      ),
                      child: const Icon(Icons.shield, size: 12, color: FColors.emeraldDk),
                    )),
                ]),
                const SizedBox(height: 20),

                const Text('VaultX', style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w900,
                    letterSpacing: 1, color: FColors.text)),
                const SizedBox(height: 4),
                const Text('Your secrets, locked and protected.',
                    style: TextStyle(color: FColors.textMuted, fontSize: 14)),
                const SizedBox(height: 40),

                // Lockout banner
                if (locked) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: FColors.redDim, borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: FColors.red.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.timer_outlined, color: FColors.red, size: 18),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Too many failed attempts',
                            style: TextStyle(color: FColors.red, fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('Try again in ${vp.lockoutSeconds}s',
                            style: const TextStyle(color: FColors.red, fontSize: 11)),
                      ]),
                    ]),
                  ),
                ],

                // Password field
                TextField(
                  controller:  _ctrl,
                  obscureText: !_showPw,
                  enabled:     !locked && !busy,
                  onSubmitted: (_) => _unlock(vp),
                  style: const TextStyle(letterSpacing: 2, color: FColors.text, fontSize: 16),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.key_outlined, color: FColors.textDim),
                    hintText:   'Master Password',
                    suffixIcon: IconButton(
                      icon: Icon(_showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: FColors.textDim, size: 20),
                      onPressed: () => setState(() => _showPw = !_showPw),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Error
                if (vp.error != null && !locked)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: FColors.redDim, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: FColors.red.withOpacity(0.25)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: FColors.red, size: 15),
                      const SizedBox(width: 8),
                      Expanded(child: Text(vp.error!,
                          style: const TextStyle(color: FColors.red, fontSize: 12))),
                    ]),
                  ),

                // Unlock
                ElevatedButton.icon(
                  onPressed: (!locked && !busy) ? () => _unlock(vp) : null,
                  icon: busy
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: FColors.emeraldDk))
                      : const Icon(Icons.lock_open_outlined),
                  label: Text(busy ? 'Unlocking…' : 'UNLOCK VAULT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: locked ? FColors.surfaceAlt : FColors.emerald,
                    foregroundColor: locked ? FColors.textDim    : FColors.emeraldDk,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
                const SizedBox(height: 10),

                // Cloud restore (if signed in)
                if (vp.currentUser != null) ...[
                  _SecBtn(
                    icon: const Icon(Icons.cloud_download_outlined,
                        size: 15, color: FColors.textMuted),
                    label: 'RESTORE FROM CLOUD',
                    onTap: () => vp.restoreFromCloud(_ctrl.text),
                    disabled: busy || _ctrl.text.isEmpty,
                  ),
                  const SizedBox(height: 8),
                  // Signed-in account chip
                  Center(child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: FColors.blueDim, borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: FColors.blue.withOpacity(0.25)),
                    ),
                    child: Text(vp.currentUser!.email ?? 'Signed in',
                        style: const TextStyle(color: FColors.blue, fontSize: 11)),
                  )),
                ] else
                  // Google Sign-In
                  _SecBtn(
                    icon: vp.isSigningIn
                        ? const SizedBox(width: 15, height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2, color: FColors.textDim))
                        : const Icon(Icons.login, size: 15, color: FColors.black),
                    label: vp.isSigningIn ? 'Signing in…' : 'SIGN IN WITH GOOGLE',
                    color: vp.isSigningIn ? FColors.surface : FColors.white,
                    labelColor: vp.isSigningIn ? FColors.textMuted : FColors.black,
                    onTap: () => vp.signInWithGoogle(),
                    disabled: busy,
                  ),

                const Spacer(),

                // Footer
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(
                        color: FColors.emerald, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    const Text('End-to-end encrypted · Zero knowledge · Biometric ready',
                        style: TextStyle(color: Color(0x8D10B981), fontSize: 10,
                            fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                  ]),
                ),
              ],
            )),
          ),
        ),
      ),
    );
  }

  Future<void> _unlock(VaultProvider vp) async {
    if (_ctrl.text.isEmpty || vp.isUnlocking) return;
    await vp.unlockVault(_ctrl.text);
  }
}

class _SecBtn extends StatelessWidget {
  final Widget icon; final String label;
  final VoidCallback onTap; final bool disabled;
  final Color color, labelColor;
  const _SecBtn({required this.icon, required this.label, required this.onTap,
      this.disabled = false, this.color = FColors.surface, this.labelColor = FColors.textMuted});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: disabled ? null : onTap,
    child: Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Container(
        height: 48, width: double.infinity,
        decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FColors.border),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          icon, const SizedBox(width: 8),
          Text(label, style: TextStyle(color: labelColor,
              fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.2)),
        ]),
      ),
    ),
  );
}
