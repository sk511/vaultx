import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/vault_provider.dart';
import 'screens/lock_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/vault_screen.dart';
import 'screens/generator_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/add_edit_modal.dart';
import 'widgets/vaultx_alert.dart';
import 'models/vault_entry.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(ChangeNotifierProvider(
    create: (_) => VaultProvider()..initialize(),
    child: const VaultXApp(),
  ));
}

class VaultXApp extends StatelessWidget {
  const VaultXApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'VaultX',
    debugShowCheckedModeBanner: false,
    theme: buildVaultXTheme(),
    home: const _AppShell(),
  );
}

// ─── App Shell ────────────────────────────────────────────────────────────────
class _AppShell extends StatefulWidget {
  const _AppShell();
  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check biometric enrollment when user returns from device Settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<VaultProvider>().onResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VaultProvider>();
    return Stack(children: [
      AbsorbPointer(
        absorbing: vp.isBusy,
        child: vp.isFirstLaunch
            ? const OnboardingScreen()      // no vault yet — set up first
            : vp.isLocked
                ? const LockScreen()        // vault exists but locked
                : Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (_) => vp.resetActivity(),
                    onPointerMove: (_) => vp.resetActivity(),
                    child: _UnlockedShell(vp: vp),
                  ),
      ),

      // Loading overlay — shown during unlock / save / sync
      if (vp.isBusy && !vp.isVerifying)
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.45),
            child: Center(child: _LoadingCard(vp: vp)),
          ),
        ),

      // Biometric overlay
      if (vp.isVerifying)
        Positioned.fill(
            child: BiometricOverlay(biometricLabel: vp.biometricLabel)),

      // Alert dialog
      if (vp.alertTitle != null)
        Positioned.fill(
          child: Material(
            color: Colors.black.withOpacity(0.55),
            child: Center(child: VaultXAlert(
              title:       vp.alertTitle!,
              message:     vp.alertMessage!,
              type:        vp.alertType!,
              onDismiss:   vp.dismissAlert,
              actionLabel: vp.alertActionLabel,
              onAction:    vp.alertAction,
            )),
          ),
        ),
    ]);
  }
}

class _LoadingCard extends StatelessWidget {
  final VaultProvider vp;
  const _LoadingCard({required this.vp});

  String get _msg {
    if (vp.isUnlocking && vp.syncStatus == SyncStatus.syncing) return 'Restoring your vault…';
    if (vp.isUnlocking)                      return 'Opening vault…';
    if (vp.isSaving)                         return 'Securing your data…';
    if (vp.isSigningIn)                      return 'Signing in…';
    if (vp.syncStatus == SyncStatus.syncing) return 'Syncing to cloud…';
    return 'Please wait…';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
    decoration: BoxDecoration(
      color: FColors.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: FColors.borderMid),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(width: 44, height: 44,
          child: CircularProgressIndicator(color: FColors.emerald, strokeWidth: 3)),
      const SizedBox(height: 18),
      Text(_msg, style: const TextStyle(
          color: FColors.text, fontWeight: FontWeight.w600, fontSize: 15)),
      const SizedBox(height: 4),
      const Text('One moment…',
          style: TextStyle(color: FColors.textDim, fontSize: 12)),
    ]),
  );
}

// ─── Unlocked shell ───────────────────────────────────────────────────────────
class _UnlockedShell extends StatelessWidget {
  final VaultProvider vp;
  const _UnlockedShell({required this.vp});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: FColors.bg,
    appBar: AppBar(
      backgroundColor: const Color(0xF20A0A0B),
      elevation: 0, titleSpacing: 20,
      title: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: FColors.emeraldDim,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: FColors.emeraldBdr),
          ),
          child: const Icon(Icons.shield_outlined, size: 18, color: FColors.emerald),
        ),
        const SizedBox(width: 10),
        const Text('VaultX', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1,
            color: FColors.text)),
        // No duress indicator here — the vault must look identical to the real one.
      ]),
      actions: [
        IconButton(
          icon: const Icon(Icons.lock_outline, size: 20),
          color: FColors.textMuted,
          onPressed: vp.lockVault,
          tooltip: 'Lock',
        ),
      ],
    ),
    body: _BodyWithModalListener(
      child: switch (vp.activeTab) {
        ActiveTab.vault     => const VaultScreen(),
        ActiveTab.generator => const GeneratorScreen(),
        ActiveTab.settings  => const SettingsScreen(),
      },
    ),
    bottomNavigationBar: _BottomBar(vp: vp),
  );
}

class _BottomBar extends StatelessWidget {
  final VaultProvider vp;
  const _BottomBar({required this.vp});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xF50A0A0B),
      border: Border(top: BorderSide(color: FColors.border)),
    ),
    child: SafeArea(child: SizedBox(height: 60, child: Row(children: [
      _NavBtn(icon: Icons.key_rounded,    label: 'Vault',
          active: vp.activeTab == ActiveTab.vault,
          onTap: () => vp.setActiveTab(ActiveTab.vault)),
      _NavBtn(icon: Icons.bolt_rounded,   label: 'Generate',
          active: vp.activeTab == ActiveTab.generator,
          onTap: () => vp.setActiveTab(ActiveTab.generator)),
      // FAB — opens AddEditModal directly, no isAddingEntry needed
      Expanded(child: Center(child: GestureDetector(
        onTap: () {
          // Reset any stale editing state first
          vp.closeEntryModal();
          showModalBottomSheet(
            context: context, isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => ChangeNotifierProvider.value(
                value: vp, child: const AddEditModal()),
          ).then((_) => vp.closeEntryModal());
        },
        child: Container(
          width: 58, height: 58,
          decoration: BoxDecoration(
            color: FColors.emerald,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FColors.bg, width: 4),
            boxShadow: [BoxShadow(color: FColors.emerald.withOpacity(0.4),
                blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: const Icon(Icons.add, size: 28, color: FColors.emeraldDk),
        ),
      ))),
      _NavBtn(icon: Icons.tune_rounded,  label: 'Settings',
          active: vp.activeTab == ActiveTab.settings,
          onTap: () => vp.setActiveTab(ActiveTab.settings)),
      const Expanded(child: SizedBox()),
    ]))),
  );
}

class _BodyWithModalListener extends StatefulWidget {
  final Widget child;
  const _BodyWithModalListener({required this.child});
  @override
  State<_BodyWithModalListener> createState() => _BodyState();
}

class _BodyState extends State<_BodyWithModalListener> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VaultProvider>();
    // Only trigger here for EDIT flow (openEditEntry from vault card).
    // New entries are opened directly by the FAB without going through isAddingEntry.
    if (vp.isAddingEntry && vp.editingEntry != null && !_open) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        setState(() => _open = true);
        await showModalBottomSheet(
          context: context, isScrollControlled: true,
          backgroundColor: Colors.transparent, enableDrag: true,
          builder: (_) => ChangeNotifierProvider.value(
              value: context.read<VaultProvider>(), child: const AddEditModal()),
        );
        if (mounted) {
          setState(() => _open = false);
          context.read<VaultProvider>().closeEntryModal();
        }
      });
    }
    return widget.child;
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon; final String label;
  final bool active; final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.label,
      required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: onTap, behavior: HitTestBehavior.opaque,
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 22, color: active ? FColors.emerald : FColors.textDim),
      const SizedBox(height: 3),
      Text(label, style: TextStyle(
          color: active ? FColors.emerald : FColors.textDim,
          fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
    ]),
  ));
}
