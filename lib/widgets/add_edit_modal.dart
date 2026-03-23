import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vault_entry.dart';
import '../services/crypto_service.dart';
import '../services/vault_provider.dart';
import '../utils/theme.dart';

class AddEditModal extends StatefulWidget {
  const AddEditModal({super.key});
  @override
  State<AddEditModal> createState() => _AddEditModalState();
}

class _AddEditModalState extends State<AddEditModal> {
  final _titleCtrl    = TextEditingController();
  final _userCtrl     = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _urlCtrl      = TextEditingController();
  final _notesCtrl    = TextEditingController();
  final _totpCtrl     = TextEditingController();

  EntryCategory _category   = EntryCategory.password;
  bool _showCatPicker       = false;
  bool _showPass            = false;
  bool _showTotp            = false;
  bool _genPassphrase       = false;
  PasswordStrength? _strength;

  @override
  void initState() {
    super.initState();
    final vp = context.read<VaultProvider>();
    final e  = vp.editingEntry;
    if (e != null) {
      _titleCtrl.text = e.title;
      _userCtrl.text  = e.username;
      _passCtrl.text  = e.password;
      _urlCtrl.text   = e.url ?? '';
      _notesCtrl.text = e.notes ?? '';
      _totpCtrl.text  = e.totpSecret ?? '';
      _category       = e.category;
      _strength       = CryptoService.analyseStrength(e.password);
    }

    // Any typing in the modal resets the inactivity timer.
    // The modal lives above the root Listener so we must do this explicitly —
    // otherwise typing a long seed phrase or note triggers auto-lock mid-fill.
    void onAnyChange() => context.read<VaultProvider>().resetActivity();

    for (final c in [_titleCtrl, _userCtrl, _urlCtrl, _notesCtrl, _totpCtrl]) {
      c.addListener(onAnyChange);
    }

    // Title and notes also drive canSave — rebuild on change
    _titleCtrl.addListener(() => setState(() {}));
    _notesCtrl.addListener(() => setState(() {}));

    // Password drives strength meter + canSave
    _passCtrl.addListener(() {
      onAnyChange();
      setState(() {
        _strength = _passCtrl.text.isEmpty
            ? null
            : CryptoService.analyseStrength(_passCtrl.text);
      });
    });
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl, _userCtrl, _passCtrl, _urlCtrl, _notesCtrl, _totpCtrl]) c.dispose();
    super.dispose();
  }

  void _generate() {
    final pwd = _genPassphrase
        ? CryptoService.generatePassphrase()
        : CryptoService.generatePassword();
    _passCtrl.text = pwd;
    setState(() => _showPass = true);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final vp  = context.read<VaultProvider>();
    final now = DateTime.now().millisecondsSinceEpoch;
    final old = vp.editingEntry;
    final entry = VaultEntry(
      id:                old?.id ?? vp.newId(),
      title:             _titleCtrl.text.trim(),
      username:          _userCtrl.text.trim(),
      password:          _passCtrl.text,
      url:               _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
      notes:             _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      totpSecret:        _totpCtrl.text.trim().isEmpty ? null : _totpCtrl.text.trim(),
      category:          _category,
      isFavorite:        old?.isFavorite ?? false,
      breachDetected:    false,
      passwordChangedAt: old == null || old.password != _passCtrl.text
          ? now : old.passwordChangedAt,
      updatedAt: now,
      createdAt: old?.createdAt ?? now,
    );
    // vp.isSaving is set true inside addOrUpdateEntry while the Isolate runs.
    // The Save button reads it from context.watch so the spinner appears automatically.
    await vp.addOrUpdateEntry(entry);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vp      = context.watch<VaultProvider>();   // watch for isSaving updates
    final isNote  = _category == EntryCategory.note;
    final meta    = kCategoryMeta[_category]!;
    final canSave = isNote
        ? (_titleCtrl.text.trim().isNotEmpty || _notesCtrl.text.trim().isNotEmpty)
        : (_titleCtrl.text.trim().isNotEmpty && _passCtrl.text.isNotEmpty);
    final saving  = vp.isSaving;

    return DraggableScrollableSheet(
      initialChildSize: 0.92, maxChildSize: 0.97, minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: FColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: FColors.borderMid)),
        ),
        child: Column(children: [
          // Handle
          Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: FColors.textDim, borderRadius: BorderRadius.circular(2))),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(
                  color: meta.color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(meta.icon, color: meta.color, size: 18)),
              const SizedBox(width: 12),
              Text(context.read<VaultProvider>().editingEntry != null ? 'Edit Entry' : 'New Entry',
                  style: FText.title(size: 17)),
              const Spacer(),
              GestureDetector(
                onTap: () { context.read<VaultProvider>().closeEntryModal(); Navigator.pop(context); },
                child: Container(width: 32, height: 32, decoration: BoxDecoration(
                    color: const Color(0x0FFFFFFF), shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 18, color: FColors.textMuted)),
              ),
            ]),
          ),
          const Divider(color: FColors.border, height: 1),
          // Body
          Expanded(child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // Category picker
              _Label('CATEGORY'),
              GestureDetector(
                onTap: () => setState(() => _showCatPicker = !_showCatPicker),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0x0AFFFFFF),
                      borderRadius: BorderRadius.circular(16), border: Border.all(color: FColors.border)),
                  child: Row(children: [
                    Icon(meta.icon, color: meta.color, size: 18),
                    const SizedBox(width: 10),
                    Text(meta.label, style: TextStyle(color: meta.color,
                        fontWeight: FontWeight.w700, fontSize: 15)),
                    const Spacer(),
                    Icon(_showCatPicker ? Icons.expand_less : Icons.expand_more, color: FColors.textDim),
                  ]),
                ),
              ),
              if (_showCatPicker) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: EntryCategory.values.map((c) {
                  final cm = kCategoryMeta[c]!;
                  final sel = c == _category;
                  return GestureDetector(
                    onTap: () => setState(() { _category = c; _showCatPicker = false; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? cm.color.withOpacity(0.15) : const Color(0x08FFFFFF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sel ? cm.color.withOpacity(0.4) : FColors.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(cm.icon, size: 14, color: sel ? cm.color : FColors.textDim),
                        const SizedBox(width: 5),
                        Text(cm.label, style: TextStyle(color: sel ? cm.color : FColors.textDim,
                            fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  );
                }).toList()),
              ],
              const SizedBox(height: 16),

              // Title
              _Label('NAME / TITLE *'),
              _Field(ctrl: _titleCtrl, hint: 'e.g. Chase Bank, Gmail, AWS'),
              const SizedBox(height: 16),

              // Username
              if (!isNote) ...[
                _Label(_usernameLabel(_category)),
                _Field(ctrl: _userCtrl,
                    hint: _category == EntryCategory.card ? '•••• •••• •••• ••••' : 'user@example.com',
                    keyboardType: _category == EntryCategory.card || _category == EntryCategory.bank
                        ? TextInputType.number : TextInputType.emailAddress),
                const SizedBox(height: 16),

                // Password
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _LabelWidget(_passLabel(_category)),
                  if (_category == EntryCategory.password || _category == EntryCategory.wifi)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      _GenModeBtn(label: 'Random', active: !_genPassphrase,
                          onTap: () => setState(() => _genPassphrase = false)),
                      _GenModeBtn(label: 'Phrase', active: _genPassphrase,
                          onTap: () => setState(() => _genPassphrase = true)),
                    ]),
                ]),
                _PasswordField(ctrl: _passCtrl, show: _showPass,
                    onToggle: () => setState(() => _showPass = !_showPass)),
                if (_category == EntryCategory.password || _category == EntryCategory.wifi) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _generate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: FColors.emeraldDim,
                          borderRadius: BorderRadius.circular(10), border: Border.all(color: FColors.emeraldBdr)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.refresh, size: 14, color: FColors.emerald),
                        const SizedBox(width: 6),
                        Text('GENERATE ${_genPassphrase ? 'PASSPHRASE' : 'PASSWORD'}',
                            style: const TextStyle(color: FColors.emerald,
                                fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ]),
                    ),
                  ),
                ],
                // Strength meter
                if (_strength != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Text(_strength!.label, style: TextStyle(
                        color: Color(_strength!.color), fontWeight: FontWeight.w800, fontSize: 11)),
                    const SizedBox(width: 6),
                    Text('${_strength!.entropy} bits · ${_strength!.crackTime}',
                        style: const TextStyle(color: FColors.textDim, fontSize: 10)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: List.generate(5, (i) => Expanded(child: Container(
                    height: 5, margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: i < _strength!.score ? Color(_strength!.color) : FColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )))),
                  if (_strength!.suggestions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ..._strength!.suggestions.map((s) => Row(children: [
                      const Icon(Icons.arrow_forward_ios, size: 10, color: FColors.amber),
                      const SizedBox(width: 4),
                      Text(s, style: const TextStyle(color: FColors.amber, fontSize: 10)),
                    ])),
                  ],
                ],
                const SizedBox(height: 16),
              ],

              // URL
              if (_category == EntryCategory.password || _category == EntryCategory.bank) ...[
                _Label('WEBSITE URL (OPTIONAL)'),
                _Field(ctrl: _urlCtrl, hint: 'https://example.com',
                    keyboardType: TextInputType.url),
                const SizedBox(height: 16),
              ],

              // TOTP
              if (!isNote) ...[
                GestureDetector(
                  onTap: () => setState(() => _showTotp = !_showTotp),
                  child: Row(children: [
                    _LabelWidget('2FA / TOTP SECRET (OPTIONAL)'),
                    const Spacer(),
                    Icon(_showTotp ? Icons.expand_less : Icons.expand_more,
                        size: 14, color: FColors.textDim),
                  ]),
                ),
                if (_showTotp) ...[
                  const SizedBox(height: 8),
                  _Field(ctrl: _totpCtrl, hint: 'JBSWY3DPEHPK3PXP (base32)',
                      caps: TextCapitalization.characters),
                  const SizedBox(height: 4),
                  const Text('Scan your 2FA QR code with a camera app to reveal the text secret.',
                      style: TextStyle(color: FColors.textDim, fontSize: 10)),
                ],
                const SizedBox(height: 16),
              ],

              // Notes
              _Label(isNote ? 'SECURE NOTE *' : 'NOTES (OPTIONAL)'),
              _NotesField(ctrl: _notesCtrl, isRequired: isNote),
              const SizedBox(height: 24),

              // Buttons
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () { context.read<VaultProvider>().closeEntryModal(); Navigator.pop(context); },
                  style: OutlinedButton.styleFrom(foregroundColor: FColors.textMuted,
                      side: const BorderSide(color: FColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size(0, 52)),
                  child: const Text('CANCEL'),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: canSave && !saving ? _save : null,
                  child: saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: FColors.emeraldDk))
                      : Text(vp.editingEntry != null ? 'SAVE CHANGES' : 'SECURE SAVE'),
                )),
              ]),
            ],
          )),
        ]),
      ),
    );
  }

  String _usernameLabel(EntryCategory c) => switch (c) {
    EntryCategory.bank     => 'ACCOUNT NUMBER / USERNAME',
    EntryCategory.card     => 'CARD NUMBER',
    EntryCategory.wifi     => 'NETWORK NAME (SSID)',
    EntryCategory.ssh      => 'USERNAME / HOST',
    _                      => 'USERNAME / EMAIL',
  };

  String _passLabel(EntryCategory c) => switch (c) {
    EntryCategory.card     => 'CVV / PIN',
    EntryCategory.wifi     => 'WI-FI PASSWORD',
    EntryCategory.ssh      => 'PRIVATE KEY / PASSPHRASE',
    EntryCategory.crypto   => 'SEED PHRASE / PRIVATE KEY',
    _                      => 'PASSWORD *',
  };
}

// ─── Small helpers ────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: FText.label()),
  );
}

class _LabelWidget extends StatelessWidget {
  final String text;
  const _LabelWidget(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: FText.label());
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final TextInputType? keyboardType;
  final TextCapitalization caps;
  const _Field({required this.ctrl, required this.hint,
      this.keyboardType, this.caps = TextCapitalization.none});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, style: const TextStyle(color: FColors.text),
    keyboardType: keyboardType, textCapitalization: caps,
    decoration: InputDecoration(hintText: hint),
  );
}

class _PasswordField extends StatelessWidget {
  final TextEditingController ctrl;
  final bool show;
  final VoidCallback onToggle;
  const _PasswordField({required this.ctrl, required this.show, required this.onToggle});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, obscureText: !show,
    style: const TextStyle(color: FColors.text),
    decoration: InputDecoration(
      hintText: '••••••••••••',
      suffixIcon: IconButton(
        icon: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: FColors.textDim, size: 19),
        onPressed: onToggle,
      ),
    ),
  );
}

class _NotesField extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isRequired;
  const _NotesField({required this.ctrl, required this.isRequired});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, maxLines: isRequired ? 6 : 3,
    style: const TextStyle(color: FColors.text),
    decoration: InputDecoration(hintText: isRequired ? 'Write your secure note here…' : 'Additional notes…'),
  );
}

class _GenModeBtn extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap;
  const _GenModeBtn({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? FColors.emeraldDim : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: active ? FColors.emeraldBdr : FColors.border),
      ),
      child: Text(label, style: TextStyle(
          color: active ? FColors.emerald : FColors.textDim,
          fontSize: 10, fontWeight: FontWeight.w700)),
    ),
  );
}
