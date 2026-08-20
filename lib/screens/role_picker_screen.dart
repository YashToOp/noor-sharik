import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../data/sharik_repository.dart';
import '../widgets/common.dart';
import 'orders_inbox_screen.dart';

/// Launch screen. No auth for the demo — pick a role, then pick the house.
///
/// Client and QC are listed because all three surfaces share one system; they
/// live in Noor Majlis and the QC dashboard, not here.
class RolePickerScreen extends StatelessWidget {
  const RolePickerScreen({super.key, this.repository});

  /// Injectable so the whole flow can be rendered from fixtures.
  final SharikRepository? repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NoorSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: NoorSpacing.xl),
              Text('NOOR', style: NoorText.label.copyWith(color: NoorColors.gold)),
              const SizedBox(height: NoorSpacing.xs),
              const Text('Sharik', style: NoorText.hero),
              const SizedBox(height: NoorSpacing.sm),
              Text(
                'Choose how you are signing in.',
                style: NoorText.body.copyWith(color: NoorColors.inkSoft),
              ),
              const SizedBox(height: NoorSpacing.xl),
              _RoleTile(
                title: 'Client',
                subtitle: 'Browse, basket, approve — opens Noor Majlis',
                colour: NoorColors.grey,
                enabled: false,
                onTap: () {},
              ),
              const SizedBox(height: NoorSpacing.sm),
              _RoleTile(
                title: 'Seller',
                subtitle: 'Your orders, your production, your money',
                colour: NoorColors.forest,
                enabled: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _HousePickerScreen(repository: repository),
                  ),
                ),
              ),
              const SizedBox(height: NoorSpacing.sm),
              _RoleTile(
                title: 'QC',
                subtitle: 'Gates and the live board — opens the QC dashboard',
                colour: NoorColors.grey,
                enabled: false,
                onTap: () {},
              ),
              const Spacer(),
              Row(
                children: [
                  for (final lang in const ['English', 'العربية', 'हिन्दी'])
                    Padding(
                      padding: const EdgeInsets.only(right: NoorSpacing.sm),
                      child: Pill(
                        text: lang,
                        colour: lang == 'English'
                            ? NoorColors.forest
                            : NoorColors.inkFaint,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: NoorSpacing.sm),
              Text(
                'English only for this build.',
                style: NoorText.body.copyWith(
                  color: NoorColors.inkFaint,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.title,
    required this.subtitle,
    required this.colour,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color colour;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: NoorCard(
        onTap: enabled ? onTap : null,
        accent: enabled ? colour : null,
        padding: const EdgeInsets.all(NoorSpacing.md + 2),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 44,
              decoration: BoxDecoration(
                color: colour,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: NoorSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: NoorText.title),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: NoorText.body.copyWith(
                      color: NoorColors.inkSoft,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (enabled)
              const Icon(Icons.chevron_right, color: NoorColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _HousePickerScreen extends StatefulWidget {
  const _HousePickerScreen({this.repository});

  final SharikRepository? repository;

  @override
  State<_HousePickerScreen> createState() => _HousePickerScreenState();
}

class _HousePickerScreenState extends State<_HousePickerScreen> {
  late final SharikRepository _repo =
      widget.repository ?? SharikRepository(Supabase.instance.client);
  late Future<List<House>> _future = _repo.houses();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Which house?')),
      body: FutureBuilder<List<House>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorState(
              onRetry: () => setState(() => _future = _repo.houses()),
            );
          }
          final houses = snap.data ?? const <House>[];
          if (houses.isEmpty) {
            return const EmptyState(
              title: 'No houses yet',
              message: 'Nothing has been set up for this tenant.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(NoorSpacing.md),
            itemCount: houses.length,
            separatorBuilder: (_, __) => const SizedBox(height: NoorSpacing.sm),
            itemBuilder: (context, i) {
              final h = houses[i];
              return NoorCard(
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => OrdersInboxScreen(
                      house: h,
                      repository: widget.repository,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: NoorColors.forest.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(NoorRadius.md),
                      ),
                      child: Center(
                        child: Text(
                          h.code,
                          style: NoorText.label.copyWith(
                            color: NoorColors.forest,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: NoorSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h.name, style: NoorText.title),
                          Text(
                            h.city,
                            style: NoorText.body.copyWith(
                              color: NoorColors.inkSoft,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: NoorColors.inkFaint),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const EmptyState(
            title: 'Cannot reach Noor',
            message: 'Check the connection and try again.',
            tint: NoorColors.danger,
          ),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
