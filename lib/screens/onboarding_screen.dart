import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vault_provider.dart';
import '../services/crypto_service.dart';
import '../utils/theme.dart';

// ─── Onboarding + first-launch password setup ────────────────────────────────
// Shown only once — when no vault exists in storage.
// After the user sets their master password here, the vault is initialised
// and they go straight into the app. Never shown again.

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page       = 0;

  // Setup page state
  final _pwCtrl      = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool  _showPw      = false;
  bool  _showConfirm = false;
  bool  _creating    = false;
  PasswordStrength? _strength;

  @override
  void dispose() {
    _pageCtrl.dispose(); _pwCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 3) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  Future<void> _create() async {
    final pw      = _pwCtrl.text;
    final confirm = _confirmCtrl.text;
    if (pw.isEmpty || pw != confirm) return;
    if (_creating) return;

    setState(() => _creating = true);
    try {
      final vp = context.read<VaultProvider>();
      await vp.createVault(pw);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FColors.bg,
      body: SafeArea(
        child: Column(children: [
          // Progress dots
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ...List.generate(4, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width:  _page == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _page == i ? FColors.emerald : FColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ]),
          ),

          // Pages
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                _PageOne(onNext: _next),
                _PageTwo(onNext: _next),
                _PageThree(onNext: _next),
                _SetupPage(
                  pwCtrl: _pwCtrl, confirmCtrl: _confirmCtrl,
                  showPw: _showPw, showConfirm: _showConfirm,
                  strength: _strength, creating: _creating,
                  onTogglePw:      () => setState(() => _showPw      = !_showPw),
                  onToggleConfirm: () => setState(() => _showConfirm = !_showConfirm),
                  onPwChanged: (v) => setState(() =>
                      _strength = v.isEmpty ? null : CryptoService.analyseStrength(v)),
                  onConfirmChanged: (_) => setState(() {}),
                  onCreate: _create,
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Page 1 — Welcome ─────────────────────────────────────────────────────────
class _PageOne extends StatelessWidget {
  final VoidCallback onNext;
  const _PageOne({required this.onNext});

  @override
  Widget build(BuildContext context) => _OnboardPage(
    icon: Icons.shield_rounded,
    iconColor: FColors.emerald,
    iconBg: FColors.emeraldDim,
    title: 'Welcome to VaultX',
    subtitle: 'The password manager that keeps your secrets — and never shares them.',
    bullets: const [
      (Icons.lock_rounded,         'Everything is encrypted on your device'),
      (Icons.cloud_off_rounded,    'Your passwords never travel unencrypted'),
      (Icons.visibility_off_rounded, 'Even we can\'t read your data'),
    ],
    buttonLabel: 'GET STARTED',
    onTap: onNext,
  );
}

// ─── Page 2 — How it works ────────────────────────────────────────────────────
class _PageTwo extends StatelessWidget {
  final VoidCallback onNext;
  const _PageTwo({required this.onNext});

  @override
  Widget build(BuildContext context) => _OnboardPage(
    icon: Icons.key_rounded,
    iconColor: FColors.blue,
    iconBg: FColors.blueDim,
    title: 'One Master Password',
    subtitle: 'One strong password unlocks everything. It never leaves your device.',
    bullets: const [
      (Icons.fingerprint,          'Use your fingerprint or face after setup'),
      (Icons.sync_rounded,         'Optionally back up to your Google account'),
      (Icons.generating_tokens,    'Built-in 2FA codes — no extra app needed'),
    ],
    buttonLabel: 'NEXT',
    onTap: onNext,
  );
}

// ─── Page 3 — The critical warning ───────────────────────────────────────────
class _PageThree extends StatelessWidget {
  final VoidCallback onNext;
  const _PageThree({required this.onNext});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
    child: Column(children: [
      // Warning icon
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: FColors.amberDim,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: FColors.amber.withOpacity(0.3)),
        ),
        child: const Icon(Icons.warning_rounded, color: FColors.amber, size: 40),
      ),
      const SizedBox(height: 24),
      const Text('Read This First', style: TextStyle(
          color: FColors.text, fontSize: 26, fontWeight: FontWeight.w900,
          letterSpacing: -0.5)),
      const SizedBox(height: 8),
      const Text('Before you create your master password:',
          style: TextStyle(color: FColors.textMuted, fontSize: 15),
          textAlign: TextAlign.center),
      const SizedBox(height: 28),

      // Warning cards
      _WarnCard(
        icon: Icons.no_accounts_rounded,
        color: FColors.red,
        title: 'There is no "Forgot Password"',
        body: 'VaultX uses zero-knowledge encryption. '
              'We have no record of your password and no way to reset it. '
              'If you forget your master password, your data cannot be recovered by anyone.',
      ),
      const SizedBox(height: 12),
      _WarnCard(
        icon: Icons.save_rounded,
        color: FColors.amber,
        title: 'Write it down somewhere safe',
        body: 'Store your master password in a physical location — '
              'written on paper, kept in a secure place. '
              'This is the single most important thing you can do.',
      ),
      const SizedBox(height: 12),
      _WarnCard(
        icon: Icons.edit_note_rounded,
        color: FColors.emerald,
        title: 'Make it strong and memorable',
        body: 'Use a passphrase — 4 or more random words — rather than a short complex password. '
              'Easier to remember, harder to crack. '
              'Example: purple-castle-lantern-frost',
      ),
      const SizedBox(height: 32),

      ElevatedButton(
        onPressed: onNext,
        style: ElevatedButton.styleFrom(
          backgroundColor: FColors.amber,
          foregroundColor: const Color(0xFF451A03),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('I UNDERSTAND — SET UP MY VAULT',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      ),
    ]),
  );
}

// ─── Page 4 — Password setup ──────────────────────────────────────────────────
class _SetupPage extends StatelessWidget {
  final TextEditingController pwCtrl, confirmCtrl;
  final bool showPw, showConfirm, creating;
  final PasswordStrength? strength;
  final VoidCallback onTogglePw, onToggleConfirm, onCreate;
  final ValueChanged<String> onPwChanged, onConfirmChanged;

  const _SetupPage({
    required this.pwCtrl, required this.confirmCtrl,
    required this.showPw, required this.showConfirm,
    required this.strength, required this.creating,
    required this.onTogglePw, required this.onToggleConfirm,
    required this.onPwChanged, required this.onConfirmChanged,
    required this.onCreate,
  });

  bool get _mismatch =>
      confirmCtrl.text.isNotEmpty && pwCtrl.text != confirmCtrl.text;
  bool get _canCreate =>
      pwCtrl.text.length >= 4 && pwCtrl.text == confirmCtrl.text;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Create Your\nMaster Password', style: TextStyle(
          color: FColors.text, fontSize: 28, fontWeight: FontWeight.w900,
          height: 1.2, letterSpacing: -0.5)),
      const SizedBox(height: 8),
      const Text('This is the only password you need to remember.',
          style: TextStyle(color: FColors.textMuted, fontSize: 14)),
      const SizedBox(height: 28),

      // Password field
      const Text('MASTER PASSWORD', style: TextStyle(
          color: FColors.textDim, fontSize: 10,
          fontWeight: FontWeight.w800, letterSpacing: 1.5)),
      const SizedBox(height: 6),
      TextField(
        controller: pwCtrl, obscureText: !showPw,
        onChanged: onPwChanged,
        style: const TextStyle(color: FColors.text, letterSpacing: 1),
        decoration: InputDecoration(
          hintText: 'Enter master password',
          suffixIcon: IconButton(
            icon: Icon(showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: FColors.textDim, size: 20),
            onPressed: onTogglePw,
          ),
        ),
      ),

      // Strength meter
      if (strength != null) ...[
        const SizedBox(height: 10),
        Row(children: [
          Text(strength!.label, style: TextStyle(
              color: Color(strength!.color), fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(width: 8),
          Text('${strength!.entropy} bits · cracks in ${strength!.crackTime}',
              style: const TextStyle(color: FColors.textDim, fontSize: 11)),
        ]),
        const SizedBox(height: 6),
        Row(children: List.generate(5, (i) => Expanded(child: Container(
          height: 5, margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
          decoration: BoxDecoration(
            color: i < strength!.score ? Color(strength!.color) : FColors.surfaceAlt,
            borderRadius: BorderRadius.circular(3),
          ),
        )))),
        if (strength!.suggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...strength!.suggestions.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(children: [
              const Icon(Icons.arrow_forward_ios, size: 10, color: FColors.amber),
              const SizedBox(width: 5),
              Text(s, style: const TextStyle(color: FColors.amber, fontSize: 11)),
            ]),
          )),
        ],
      ],
      const SizedBox(height: 20),

      // Confirm field
      const Text('CONFIRM PASSWORD', style: TextStyle(
          color: FColors.textDim, fontSize: 10,
          fontWeight: FontWeight.w800, letterSpacing: 1.5)),
      const SizedBox(height: 6),
      TextField(
        controller: confirmCtrl, obscureText: !showConfirm,
        onChanged: onConfirmChanged,
        style: const TextStyle(color: FColors.text, letterSpacing: 1),
        decoration: InputDecoration(
          hintText: 'Re-enter master password',
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            if (confirmCtrl.text.isNotEmpty)
              Icon(
                _mismatch ? Icons.close : Icons.check_circle,
                color: _mismatch ? FColors.red : FColors.emerald,
                size: 20,
              ),
            IconButton(
              icon: Icon(showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: FColors.textDim, size: 20),
              onPressed: onToggleConfirm,
            ),
          ]),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
                color: _mismatch ? FColors.red : FColors.emerald, width: 1.5),
          ),
        ),
      ),

      if (_mismatch) ...[
        const SizedBox(height: 6),
        const Row(children: [
          Icon(Icons.error_outline, color: FColors.red, size: 14),
          SizedBox(width: 6),
          Text('Passwords do not match', style: TextStyle(color: FColors.red, fontSize: 12)),
        ]),
      ],
      const SizedBox(height: 28),

      // Critical reminder
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FColors.redDim,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FColors.red.withOpacity(0.2)),
        ),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.warning_amber_rounded, color: FColors.red, size: 18),
          SizedBox(width: 10),
          Expanded(child: Text(
            'There is no way to recover this password if forgotten. '
            'Store it somewhere safe before continuing.',
            style: TextStyle(color: FColors.red, fontSize: 12, height: 1.5),
          )),
        ]),
      ),
      const SizedBox(height: 20),

      // Create button
      ElevatedButton(
        onPressed: _canCreate && !creating ? onCreate : null,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: creating
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: FColors.emeraldDk))
            : const Text('CREATE MY VAULT',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      ),
    ]),
  );
}

// ─── Reusable onboard page layout ─────────────────────────────────────────────
class _OnboardPage extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, subtitle, buttonLabel;
  final List<(IconData, String)> bullets;
  final VoidCallback onTap;

  const _OnboardPage({
    required this.icon, required this.iconColor, required this.iconBg,
    required this.title, required this.subtitle, required this.buttonLabel,
    required this.bullets, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
    child: Column(children: [
      const Spacer(),
      Container(
        width: 88, height: 88,
        decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(28),
            border: Border.all(color: iconColor.withOpacity(0.3))),
        child: Icon(icon, color: iconColor, size: 44),
      ),
      const SizedBox(height: 28),
      Text(title, style: const TextStyle(
          color: FColors.text, fontSize: 28, fontWeight: FontWeight.w900,
          letterSpacing: -0.5, height: 1.1),
          textAlign: TextAlign.center),
      const SizedBox(height: 12),
      Text(subtitle, style: const TextStyle(
          color: FColors.textMuted, fontSize: 15, height: 1.5),
          textAlign: TextAlign.center),
      const SizedBox(height: 36),

      // Bullet points
      ...bullets.map((b) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: FColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(b.$1, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(b.$2, style: const TextStyle(
              color: FColors.textMuted, fontSize: 14, height: 1.4))),
        ]),
      )),

      const Spacer(),
      ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(buttonLabel,
            style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      ),
    ]),
  );
}

// ─── Warning card ─────────────────────────────────────────────────────────────
class _WarnCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, body;
  const _WarnCard({required this.icon, required this.color,
      required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0x06FFFFFF),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: FColors.border),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(
            color: color, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 5),
        Text(body, style: const TextStyle(
            color: FColors.textMuted, fontSize: 12, height: 1.5)),
      ])),
    ]),
  );
}
