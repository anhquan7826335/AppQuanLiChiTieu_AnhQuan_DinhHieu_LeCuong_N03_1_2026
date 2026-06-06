import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../utils/constants.dart'; // dùng AppConfig.baseUrl

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_loadedOnce) {
        _loadedOnce = true;
        ref.read(profileServiceProvider).ensureLoaded();
      }
    });
  }

  String _absUrl(String raw) {
    if (raw.isEmpty) return raw;
    final s = raw.trim();
    if (s.startsWith('http://') || s.startsWith('https://') || s.startsWith('file:')) {
      return s;
    }
    final base = AppConfig.baseUrl;
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = s.startsWith('/') ? s.substring(1) : s;
    return '$b/$p';
  }

  ImageProvider? _avatarProvider(String? urlOrPath) {
    if (urlOrPath == null || urlOrPath.trim().isEmpty) return null;
    final s = urlOrPath.trim();

    if (s.startsWith('file://')) {
      final path = s.replaceFirst('file://', '');
      final f = File(path);
      return f.existsSync() ? FileImage(f) : null;
    }
    if (!s.contains('://') && (s.startsWith('/') || s.contains(Platform.pathSeparator))) {
      final f = File(s);
      if (f.existsSync()) return FileImage(f);
      return NetworkImage(_absUrl(s));
    }
    if (s.startsWith('http://') || s.startsWith('https://')) {
      return NetworkImage(s);
    }
    return NetworkImage(_absUrl(s));
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  String _normalizeGender(String? g) {
    if (g == null) return '';
    final s = g.trim().toLowerCase();
    if (s.isEmpty) return '';
    if (s == 'nam' || s == 'male' || s == 'm' || s == '1' || s == 'true') return 'nam';
    if (s == 'nữ' || s == 'nu' || s == 'female' || s == 'f' || s == '0' || s == 'false') return 'nữ';
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileServiceProvider);
    final auth = ref.watch(authServiceProvider);

    final name = (profile.name ?? auth.currentUser?.displayName ?? '').trim();
    final email = (auth.currentUser?.email ?? '').trim();
    final avatarUrlOrPath = (profile.avatarUrl ?? '').trim();

    final birthDate = profile.birthDate;
    final genderNorm = _normalizeGender(profile.gender);

    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản'), centerTitle: true),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (ctx, c) {
            final maxW = c.maxWidth;
            final contentW = maxW < 900 ? maxW : 820.0;
            final pad = maxW < 600 ? 16.0 : 24.0;
            final avatarRadius = maxW < 600 ? 56.0 : 64.0;

            final veryNarrow = maxW <= 360;
            final pillHeight = veryNarrow ? 72.0 : (maxW < 600 ? 82.0 : 96.0);
            final iconSize = veryNarrow ? 22.0 : (maxW < 600 ? 26.0 : 30.0);
            final iconCircleRadius = veryNarrow ? 18.0 : (maxW < 600 ? 20.0 : 22.0);

            final imgProvider = _avatarProvider(avatarUrlOrPath);

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(pad),
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentW),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ===== Banner + avatar =====
                      Card(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withOpacity(.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: SizedBox(
                          height: maxW < 600 ? 180 : 200,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: avatarRadius,
                                backgroundColor: Colors.black.withOpacity(.08),
                                backgroundImage: imgProvider,
                                child: imgProvider == null
                                    ? Icon(
                                  Icons.person,
                                  size: avatarRadius,
                                  color: Colors.green.shade900,
                                )
                                    : null,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                name.isEmpty ? '—' : name,
                                style: Theme.of(context).textTheme.titleLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      _RowInfo(label: 'Họ Tên', value: name.isEmpty ? '—' : name),
                      const _DividerThin(),
                      _RowInfo(label: 'Email', value: email.isNotEmpty ? email : '—'),
                      const _DividerThin(),
                      _RowInfo(label: 'Ngày Sinh', value: _fmtDate(birthDate)),
                      const _DividerThin(),

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text('Giới Tính', style: Theme.of(context).textTheme.titleSmall),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 5,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _GenderPill(
                                      label: 'Nam',
                                      selected: genderNorm == 'nam',
                                      height: pillHeight,
                                      iconSize: iconSize,
                                      iconCircleRadius: iconCircleRadius,
                                      color: const Color(0xFF57B8FF),
                                      female: false,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _GenderPill(
                                      label: 'Nữ',
                                      selected: genderNorm == 'nữ',
                                      height: pillHeight,
                                      iconSize: iconSize,
                                      iconCircleRadius: iconCircleRadius,
                                      color: const Color(0xFFFF77A9),
                                      female: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RowInfo extends StatelessWidget {
  final String label;
  final String value;
  const _RowInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DividerThin extends StatelessWidget {
  const _DividerThin();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.onSurface.withOpacity(.08),
    );
  }
}

class _GenderPill extends StatelessWidget {
  final String label;
  final bool selected;
  final double height;
  final double iconSize;
  final double iconCircleRadius;
  final Color color;
  final bool female;

  const _GenderPill({
    required this.label,
    required this.selected,
    required this.height,
    required this.iconSize,
    required this.iconCircleRadius,
    required this.color,
    this.female = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? color.withOpacity(.10)
        : Theme.of(context).colorScheme.surface;
    final border = selected
        ? Border.all(color: color.withOpacity(.70), width: 2)
        : Border.all(
      color: Theme.of(context).colorScheme.outlineVariant.withOpacity(.6),
      width: 1.2,
    );
    final textStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurface,
    );

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: border,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: iconCircleRadius,
            backgroundColor:
            selected ? color.withOpacity(.25) : color.withOpacity(.18),
            child: Icon(female ? Icons.female : Icons.male, size: iconSize, color: color),
          ),
          const SizedBox(width: 12),
          Flexible(child: Text(label, textAlign: TextAlign.center, style: textStyle)),
        ],
      ),
    );
  }
}
