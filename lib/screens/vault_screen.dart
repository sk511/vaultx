import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vault_entry.dart';
import '../services/crypto_service.dart';
import '../services/vault_provider.dart';
import '../utils/theme.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});
  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final _searchCtrl = TextEditingController();
  EntryCategory? _filterCat;
  bool _filterFavorites = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text));
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<VaultEntry> _filtered(List<VaultEntry> all) {
    var list = all;
    if (_filterFavorites) list = list.where((e) => e.isFavorite).toList();
    else if (_filterCat != null) list = list.where((e) => e.category == _filterCat).toList();
    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((e) =>
          e.title.toLowerCase().contains(q) ||
          e.username.toLowerCase().contains(q) ||
          (e.url ?? '').toLowerCase().contains(q)).toList();
    }
    list.sort((a, b) => (b.isFavorite ? 1 : 0) - (a.isFavorite ? 1 : 0));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VaultProvider>();
    final filtered = _filtered(vp.entries);
    final breached  = vp.entries.where((e) => e.breachDetected).length;
    final agedCount = vp.entries.where((e) =>
        e.passwordChangedAt != null &&
        DateTime.now().millisecondsSinceEpoch - e.passwordChangedAt! > 90 * 86400000).length;

    return GestureDetector(
      onTap: vp.resetActivity,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          // ── Breach banner ──────────────────────────────────────────────
          if (breached > 0)
            _Banner(
              icon: Icons.warning_rounded,
              color: FColors.red,
              bgColor: FColors.redDim,
              text: '$breached password${breached > 1 ? 's' : ''} found in data breaches — tap to check',
              onTap: vp.runBreachCheck,
            ),
          if (agedCount > 0 && breached == 0)
            _Banner(
              icon: Icons.access_time_rounded,
              color: FColors.amber,
              bgColor: FColors.amberDim,
              text: '$agedCount password${agedCount > 1 ? 's are' : ' is'} over 90 days old',
            ),

          // ── Sync bar ───────────────────────────────────────────────────
          if (vp.currentUser != null) ...[
            _SyncBar(vp: vp),
            const SizedBox(height: 12),
          ],

          // ── Search ─────────────────────────────────────────────────────
          TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: FColors.text),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: FColors.textDim, size: 20),
              hintText: 'Search vault…',
              suffixIcon: _search.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 18, color: FColors.textDim),
                      onPressed: () => _searchCtrl.clear())
                  : null,
            ),
          ),
          const SizedBox(height: 12),

          // ── Category filter pills ──────────────────────────────────────
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterPill(label: 'All', icon: Icons.grid_view_rounded,
                    active: _filterCat == null && !_filterFavorites,
                    color: FColors.emerald,
                    onTap: () => setState(() { _filterCat = null; _filterFavorites = false; })),
                _FilterPill(label: 'Favorites', icon: Icons.favorite_rounded,
                    active: _filterFavorites, color: FColors.red,
                    onTap: () => setState(() { _filterFavorites = !_filterFavorites; _filterCat = null; })),
                ...EntryCategory.values.map((c) {
                  final m = kCategoryMeta[c]!;
                  return _FilterPill(
                    label: m.label, icon: m.icon,
                    active: _filterCat == c && !_filterFavorites,
                    color: m.color,
                    onTap: () => setState(() { _filterCat = c; _filterFavorites = false; }),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Count + clipboard timer ────────────────────────────────────
          Row(children: [
            Text(
              _filterFavorites ? 'FAVORITES' : _filterCat != null
                  ? kCategoryMeta[_filterCat]!.label.toUpperCase() : 'ALL',
              style: FText.label(),
            ),
            const Spacer(),
            if (vp.clipSecondsLeft > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: FColors.emeraldDim, borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: FColors.emeraldBdr),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.timer_outlined, size: 11, color: FColors.emerald),
                  const SizedBox(width: 4),
                  Text('Clears in ${vp.clipSecondsLeft}s',
                      style: const TextStyle(color: FColors.emerald, fontSize: 10, fontWeight: FontWeight.w700)),
                ]),
              )
            else
              Text('${filtered.length} items', style: FText.label()),
          ]),
          const SizedBox(height: 8),

          // ── Entries / empty state ──────────────────────────────────────
          if (filtered.isEmpty)
            _EmptyState(search: _search)
          else
            ...filtered.map((e) => _EntryCard(entry: e, vp: vp)),
        ],
      ),
    );
  }
}

// ─── Entry Card ───────────────────────────────────────────────────────────────
class _EntryCard extends StatelessWidget {
  final VaultEntry entry;
  final VaultProvider vp;
  const _EntryCard({required this.entry, required this.vp});

  @override
  Widget build(BuildContext context) {
    final meta    = kCategoryMeta[entry.category]!;
    final cc      = meta.color;
    final visible = vp.visiblePasswords.contains(entry.id);
    final copied  = vp.copiedEntryId == entry.id;
    final isNote  = entry.category == EntryCategory.note;

    final daysSinceChange = entry.passwordChangedAt != null
        ? (DateTime.now().millisecondsSinceEpoch - entry.passwordChangedAt!) ~/ 86400000
        : null;
    final isAged = daysSinceChange != null && daysSinceChange >= 90;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x06FFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: Color(cc.value).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Color(cc.value).withOpacity(0.3)),
            ),
            child: Icon(meta.icon, color: cc, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(entry.title, style: FText.title()),
              if (entry.breachDetected)
                GestureDetector(
                  onTap: () => _showBreachDetail(context, entry),
                  child: _MiniTag(
                    label: entry.breachCount > 0
                        ? 'BREACHED ${_formatBreachCount(entry.breachCount)}'
                        : 'BREACHED',
                    color: FColors.red,
                    icon: Icons.warning_rounded,
                  ),
                ),
              if (isAged)
                _MiniTag(
                  label: '${daysSinceChange}d old',
                  color: daysSinceChange! > 180 ? FColors.red : FColors.amber,
                  icon: Icons.access_time,
                ),
            ]),
            Text(entry.username, style: FText.body(size: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (entry.url != null && entry.url!.isNotEmpty)
              Text(entry.url!, style: FText.body(size: 11, color: FColors.textDim),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _IconBtn(
              icon: entry.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: entry.isFavorite ? FColors.red : FColors.textDim,
              onTap: () => vp.toggleFavorite(entry.id),
            ),
            _IconBtn(icon: Icons.edit_outlined, color: FColors.textMuted,
                onTap: () async {
                  // Require biometric/auth before showing pre-filled credentials
                  final ok = await vp.verifyIdentity();
                  if (ok) vp.openEditEntry(entry);
                }),
            _IconBtn(icon: Icons.delete_outline, color: FColors.textDim,
                bgColor: FColors.redDim,
                onTap: () => _confirmDelete(context, entry, vp)),
          ]),
        ]),
        const SizedBox(height: 12),

        // Password row
        if (!isNote) ...[
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FColors.border),
            ),
            child: Row(children: [
              const SizedBox(width: 14),
              Expanded(child: Text(
                visible ? entry.password : '••••••••••••',
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 13,
                    letterSpacing: 2, color: FColors.textMuted),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              )),
              _IconBtn(
                icon: visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: FColors.textMuted,
                onTap: () => vp.toggleVisibility(entry.id),
              ),
              _IconBtn(
                icon: copied ? Icons.check_circle : Icons.copy_outlined,
                color: copied ? FColors.emerald : FColors.textMuted,
                bgColor: copied ? FColors.emeraldDim : Colors.transparent,
                onTap: () => vp.copyPassword(entry.password, entry.id),
              ),
            ]),
          ),
          const SizedBox(height: 8),
        ],

        // TOTP
        if (entry.totpSecret != null && entry.totpSecret!.isNotEmpty)
          _TotpWidget(secret: entry.totpSecret!),

        // Secure note body
        if (isNote && entry.notes != null && entry.notes!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x08FFFFFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FColors.border),
            ),
            child: Text(entry.notes!, style: FText.body(size: 13), maxLines: 4,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 8),
        ],

        // Footer
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Color(cc.value).withOpacity(0.3)),
            ),
            child: Text(meta.label.toUpperCase(),
                style: TextStyle(color: cc, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ),
          const Spacer(),
          Text(
            _formatDate(entry.updatedAt),
            style: const TextStyle(color: FColors.textDim, fontSize: 10),
          ),
        ]),
      ]),
    );
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month-1]} ${d.year}';
  }

  String _formatBreachCount(int n) {
    if (n >= 1000000) return '${(n/1000000).toStringAsFixed(1)}M×';
    if (n >= 1000)    return '${(n/1000).toStringAsFixed(1)}K×';
    return '${n}×';
  }

  void _showBreachDetail(BuildContext context, VaultEntry entry) {
    final count = entry.breachCount;
    final checked = entry.breachCheckedAt != null
        ? _formatDate(entry.breachCheckedAt!)
        : 'Unknown';
    final severity = count > 100000 ? 'Critical' : count > 10000 ? 'High' : 'Medium';
    final severityColor = count > 100000 ? FColors.red : count > 10000 ? FColors.red : FColors.amber;

    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: FColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        const Icon(Icons.warning_rounded, color: FColors.red, size: 20),
        const SizedBox(width: 8),
        const Text('Breach Details', style: TextStyle(color: FColors.text, fontSize: 17)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _detailRow('Account', entry.title),
        _detailRow('Username', entry.username.isNotEmpty ? entry.username : '—'),
        const Divider(color: FColors.border, height: 20),
        _detailRow('Times seen in breaches',
            count > 0 ? _formatBreachCount(count) : 'Detected'),
        _detailRow('Severity', severity, valueColor: severityColor),
        _detailRow('Last checked', checked),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: FColors.redDim,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: FColors.red.withOpacity(0.2)),
          ),
          child: const Text(
            'This password appears in known data breach databases. '
            'Hackers actively use these lists in automated attacks. '
            'Change this password immediately on the affected website or app.',
            style: TextStyle(color: FColors.red, fontSize: 12, height: 1.5),
          ),
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE', style: TextStyle(color: FColors.textMuted)),
        ),
      ],
    ));
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 130, child: Text(label,
          style: const TextStyle(color: FColors.textDim, fontSize: 12))),
      Expanded(child: Text(value, style: TextStyle(
          color: valueColor ?? FColors.text,
          fontSize: 12, fontWeight: FontWeight.w600))),
    ]),
  );

  void _confirmDelete(BuildContext context, VaultEntry entry, VaultProvider vp) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: FColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Delete Entry', style: TextStyle(color: FColors.text)),
      content: Text('Delete "${entry.title}"? This cannot be undone.',
          style: const TextStyle(color: FColors.textMuted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: FColors.textMuted))),
        TextButton(onPressed: () { Navigator.pop(context); vp.deleteEntry(entry.id); },
            child: const Text('Delete', style: TextStyle(color: FColors.red))),
      ],
    ));
  }
}

// ─── TOTP Widget ──────────────────────────────────────────────────────────────
class _TotpWidget extends StatefulWidget {
  final String secret;
  const _TotpWidget({required this.secret});
  @override
  State<_TotpWidget> createState() => _TotpWidgetState();
}

class _TotpWidgetState extends State<_TotpWidget> {
  TotpResult? _result;
  Timer? _timer;
  bool _shown = false;

  void _start() {
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _result = CryptoService.generateTOTP(widget.secret));
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final urgent = _result != null && _result!.secondsRemaining < 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: FColors.blue.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FColors.blue.withOpacity(0.18)),
      ),
      child: Row(children: [
        const Icon(Icons.shield_outlined, size: 13, color: FColors.blue),
        const SizedBox(width: 6),
        const Text('2FA', style: TextStyle(color: FColors.blue, fontSize: 10,
            fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(width: 8),
        if (_shown && _result != null) ...[
          Expanded(child: Text(
            '${_result!.code.substring(0, 3)} ${_result!.code.substring(3)}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 20,
                fontWeight: FontWeight.w700, color: FColors.blue, letterSpacing: 4),
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: urgent ? FColors.red.withOpacity(0.15) : Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${_result!.secondsRemaining}s',
                style: TextStyle(
                    color: urgent ? FColors.red : FColors.emerald,
                    fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ] else
          GestureDetector(
            onTap: () { setState(() => _shown = true); _start(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: FColors.blue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('SHOW CODE',
                  style: TextStyle(color: FColors.blue, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }
}

// ─── Small helpers ────────────────────────────────────────────────────────────
class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color, bgColor;
  final String text;
  final VoidCallback? onTap;
  const _Banner({required this.icon, required this.color,
      required this.bgColor, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))),
        if (onTap != null) Icon(Icons.chevron_right, color: color, size: 14),
      ]),
    ),
  );
}

class _SyncBar extends StatelessWidget {
  final VaultProvider vp;
  const _SyncBar({required this.vp});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: FColors.emeraldDim, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: FColors.emeraldBdr),
    ),
    child: Row(children: [
      Container(width: 28, height: 28, decoration: const BoxDecoration(
          color: Color(0x26FFFFFF), shape: BoxShape.circle),
          child: const Icon(Icons.cloud_upload_outlined, size: 14, color: FColors.emerald)),
      const SizedBox(width: 10),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ENCRYPTED CLOUD SYNC', style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w800, color: FColors.emerald, letterSpacing: 1)),
        Text('Firebase · end-to-end encrypted',
            style: TextStyle(fontSize: 9, color: FColors.textDim)),
      ])),
      GestureDetector(
        onTap: vp.runBreachCheck,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: FColors.surface, borderRadius: BorderRadius.circular(6),
              border: Border.all(color: FColors.border)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.shield_outlined, size: 12, color: FColors.textMuted),
            SizedBox(width: 4),
            Text('CHECK', style: TextStyle(color: FColors.textMuted,
                fontSize: 9, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: vp.syncToCloud,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: vp.syncStatus == SyncStatus.success ? FColors.emerald : FColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: FColors.border),
          ),
          child: vp.syncStatus == SyncStatus.syncing
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: FColors.textMuted))
              : vp.syncStatus == SyncStatus.success
                  ? const Icon(Icons.check, size: 14, color: FColors.emeraldDk)
                  : const Text('SYNC', style: TextStyle(
                      color: FColors.textMuted, fontSize: 9, fontWeight: FontWeight.w800)),
        ),
      ),
    ]),
  );
}

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _FilterPill({required this.label, required this.icon,
      required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.13) : const Color(0x08FFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? color.withOpacity(0.4) : FColors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: active ? color : FColors.textDim),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(
            color: active ? color : FColors.textDim,
            fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
      ]),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final String search;
  const _EmptyState({required this.search});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.symmetric(vertical: 56),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: FColors.border, style: BorderStyle.solid, width: 2),
    ),
    child: Column(children: [
      Container(width: 60, height: 60, decoration: BoxDecoration(
          color: FColors.surface, shape: BoxShape.circle),
          child: Icon(search.isNotEmpty ? Icons.search_off : Icons.lock_outline,
              size: 28, color: FColors.textDim)),
      const SizedBox(height: 12),
      Text(search.isNotEmpty ? 'No matches' : 'Vault is empty',
          style: FText.title(size: 16, color: FColors.textMuted)),
      const SizedBox(height: 4),
      Text(search.isNotEmpty ? 'Try a different search.' : 'Tap + to add your first entry.',
          style: FText.body(color: FColors.textDim)),
    ]),
  );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.color,
      required this.onTap, this.bgColor = Colors.transparent});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(9)),
      child: Icon(icon, size: 17, color: color),
    ),
  );
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _MiniTag({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 9, color: color), const SizedBox(width: 2)],
      Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
    ]),
  );
}
