import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/admin_provider.dart';
import '../../theme/dm_tool_colors.dart';

/// Admin paneli — şu anda yalnızca yer tutucu. Built-in template publish gibi
/// admin-only akışlar buraya bağlanacak. Erişim Supabase `is_admin()` RPC'si
/// üzerinden korunur; admin olmayan kullanıcı route'a erişse bile bu ekran
/// "Access denied" gösterir.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final isAdminAsync = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: isAdminAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (isAdmin) {
          if (!isAdmin) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 64, color: palette.dangerBtnBg),
                  const SizedBox(height: 12),
                  Text('Access denied',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: palette.tabActiveText)),
                  const SizedBox(height: 4),
                  Text('Admin privileges required.',
                      style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.featureCardBg,
                  border: Border.all(color: palette.featureCardBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield, size: 24, color: palette.featureCardAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin mode active',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600, color: palette.tabActiveText)),
                          Text('You can publish updates to built-in templates.',
                              style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Built-in template editor'),
                subtitle: const Text('Edit and publish updates to the built-in D&D 5e template'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Open via Templates tab → built-in template card')),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
