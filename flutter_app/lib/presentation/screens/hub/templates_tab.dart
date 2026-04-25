import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/template_provider.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../theme/dm_tool_colors.dart';

/// Read-only templates browser. Lists the built-in D&D 5e schema with a
/// "View" button that opens the inspector. Templates are no longer
/// user-editable — there is only one template, shipped with the app.
class TemplatesTab extends ConsumerWidget {
  const TemplatesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final templatesAsync = ref.watch(allTemplatesProvider);
    final templates = templatesAsync.valueOrNull ?? const <WorldSchema>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Templates',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: palette.tabActiveText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Read-only schema reference. Open a template to inspect its categories and fields.',
                style: TextStyle(
                  fontSize: 12,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (templatesAsync.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (templates.isEmpty)
                _EmptyCard(palette: palette)
              else
                ...templates.map(
                  (schema) => _TemplateTile(
                    schema: schema,
                    palette: palette,
                    onView: () => _openInspector(context, schema),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openInspector(BuildContext context, WorldSchema schema) {
    context.push('/template/edit', extra: schema);
  }
}

class _EmptyCard extends StatelessWidget {
  final DmToolColors palette;

  const _EmptyCard({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Center(
        child: Text(
          'No templates available.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.sidebarLabelSecondary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final WorldSchema schema;
  final DmToolColors palette;
  final VoidCallback onView;

  const _TemplateTile({
    required this.schema,
    required this.palette,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final totalFields = schema.categories.fold<int>(
      0,
      (sum, c) => sum + c.fields.length,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.description, color: palette.featureCardAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  schema.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.tabActiveText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${schema.categories.length} categories · $totalFields fields',
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),
                if (schema.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    schema.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: palette.sidebarLabelSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onView,
            icon: const Icon(Icons.visibility, size: 16),
            label: const Text('View'),
          ),
        ],
      ),
    );
  }
}
