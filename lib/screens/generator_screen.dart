import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/crypto_service.dart';
import '../services/vault_provider.dart';
import '../utils/theme.dart';

class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});
  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  bool _passphraseMode = false;
  int  _length         = 20;
  int  _wordCount      = 4;
  bool _useUpper       = true;
  bool _useLower       = true;
  bool _useNumbers     = true;
  bool _useSymbols     = true;

  String _password  = '';
  PasswordStrength? _strength;
  final List<String> _history = [];

  void _generate() {
    final pwd = _passphraseMode
        ? CryptoService.generatePassphrase(wordCount: _wordCount)
        : CryptoService.generatePassword(
            length: _length, useLower: _useLower, useUpper: _useUpper,
            useNumbers: _useNumbers, useSymbols: _useSymbols);
    setState(() {
      _password = pwd;
      _strength = CryptoService.analyseStrength(pwd);
      if (_history.isEmpty || _history.first != pwd) {
        _history.insert(0, pwd);
        if (_history.length > 5) _history.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.read<VaultProvider>();
    final isCopied = vp.copiedEntryId == 'gen';

    return GestureDetector(
      onTap: vp.resetActivity,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          // Mode toggle
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: FColors.surface, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FColors.border),
            ),
            child: Row(children: [
              _ModeBtn(label: 'Random', icon: Icons.shuffle, active: !_passphraseMode,
                  onTap: () => setState(() => _passphraseMode = false)),
              _ModeBtn(label: 'Passphrase', icon: Icons.text_fields, active: _passphraseMode,
                  onTap: () => setState(() => _passphraseMode = true)),
            ]),
          ),
          const SizedBox(height: 16),

          // Password display
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: FColors.border),
            ),
            child: Row(children: [
              Expanded(child: Text(
                _password.isEmpty ? (_passphraseMode ? 'tap · generate · below' : '••••••••••••••••••••') : _password,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 17,
                    color: FColors.emerald, letterSpacing: 1.5),
                maxLines: 2,
              )),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _password.isNotEmpty ? () => vp.copyPassword(_password, 'gen') : null,
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: isCopied ? FColors.emerald : FColors.emeraldDim,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(isCopied ? Icons.check_circle : Icons.copy_outlined,
                      color: isCopied ? FColors.emeraldDk : FColors.emerald),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // Strength meter
          if (_strength != null) ...[
            FCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(_strength!.label,
                      style: TextStyle(color: Color(_strength!.color),
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(width: 8),
                  Text('${_strength!.entropy} bits',
                      style: const TextStyle(color: FColors.textDim, fontSize: 12)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Color(_strength!.color).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Color(_strength!.color).withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.timer_outlined, size: 11, color: Color(_strength!.color)),
                      const SizedBox(width: 4),
                      Text(_strength!.crackTime, style: TextStyle(
                          color: Color(_strength!.color), fontSize: 10, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Row(children: List.generate(5, (i) => Expanded(child: Container(
                    height: 6,
                    color: i < _strength!.score ? Color(_strength!.color) : FColors.surfaceAlt,
                    margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                  )))),
                ),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          // Options card
          FCard(
            padding: EdgeInsets.zero,
            child: _passphraseMode
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('WORD COUNT', style: FText.label()),
                      const SizedBox(height: 10),
                      Row(children: [3, 4, 5, 6].map((w) => _LenBtn(
                        label: '$w', active: _wordCount == w,
                        onTap: () => setState(() => _wordCount = w),
                      )).toList()),
                      const SizedBox(height: 12),
                      Text('Passphrases are memorable and strong. Words separated by dashes.',
                          style: FText.body(size: 12)),
                    ]),
                  )
                : Column(children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('LENGTH', style: FText.label()),
                        const SizedBox(height: 10),
                        Row(children: [12, 16, 20, 24, 32].map((l) => _LenBtn(
                          label: '$l', active: _length == l,
                          onTap: () => setState(() => _length = l),
                        )).toList()),
                      ]),
                    ),
                    const Divider(color: FColors.border, height: 1),
                    ...[
                      ('Uppercase (A–Z)',  _useUpper,   (v) => setState(() => _useUpper   = v)),
                      ('Lowercase (a–z)',  _useLower,   (v) => setState(() => _useLower   = v)),
                      ('Numbers (0–9)',    _useNumbers, (v) => setState(() => _useNumbers = v)),
                      ('Symbols (!@#…)',   _useSymbols, (v) => setState(() => _useSymbols = v)),
                    ].map((t) => _ToggleRow(label: t.$1, value: t.$2, onChanged: t.$3)),
                  ]),
          ),
          const SizedBox(height: 16),

          // Generate button
          ElevatedButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_passphraseMode ? 'GENERATE PASSPHRASE' : 'GENERATE PASSWORD'),
          ),
          const SizedBox(height: 16),

          // History
          if (_history.isNotEmpty) ...[
            FCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.history, size: 14, color: FColors.textDim),
                  const SizedBox(width: 6),
                  Text('RECENT (THIS SESSION)', style: FText.label()),
                ]),
                const SizedBox(height: 10),
                ..._history.map((h) => GestureDetector(
                  onTap: () { setState(() => _password = h); vp.copyPassword(h, 'gen'); },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0x08FFFFFF), borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      Expanded(child: Text(h, style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12,
                          color: FColors.textMuted, letterSpacing: 1),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const Icon(Icons.copy_outlined, size: 14, color: FColors.textDim),
                    ]),
                  ),
                )),
                const SizedBox(height: 4),
                Center(child: Text('History cleared when vault locks.',
                    style: FText.body(size: 10, color: FColors.textDim))),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // Tips
          FCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SECURITY TIPS', style: FText.label()),
              const SizedBox(height: 10),
              ...[
                'Use a unique password for every account',
                '20+ characters = virtually uncrackable',
                'Passphrases are great for master passwords you must memorize',
                'Generation is entirely offline — passwords never leave your device',
              ].map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: FColors.emerald),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tip, style: FText.body(size: 13))),
                ]),
              )),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ModeBtn extends StatelessWidget {
  final String label; final IconData icon; final bool active; final VoidCallback onTap;
  const _ModeBtn({required this.label, required this.icon, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: Container(
      height: 44,
      decoration: BoxDecoration(
        color: active ? FColors.emeraldDim : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 15, color: active ? FColors.emerald : FColors.textDim),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: active ? FColors.emerald : FColors.textDim,
            fontWeight: FontWeight.w700, fontSize: 14)),
      ]),
    ),
  ));
}

class _LenBtn extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap;
  const _LenBtn({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: Container(
      height: 38, margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: active ? FColors.emeraldDim : const Color(0x08FFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? FColors.emeraldBdr : FColors.border),
      ),
      child: Center(child: Text(label, style: TextStyle(
          color: active ? FColors.emerald : FColors.textMuted,
          fontWeight: FontWeight.w700, fontSize: 13))),
    ),
  ));
}

class _ToggleRow extends StatelessWidget {
  final String label; final bool value; final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(children: [
      Text(label, style: FText.body()),
      const Spacer(),
      Switch(value: value, onChanged: onChanged),
    ]),
  );
}
