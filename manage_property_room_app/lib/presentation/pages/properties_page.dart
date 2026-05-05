import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/notifiers/notifiers.dart';
import '../../core/property_visuals.dart';
import '../../core/responsive.dart';
import '../../domain/domain.dart';

class PropertiesPage extends ConsumerWidget {
  const PropertiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final props = ref.watch(visiblePropertiesProvider);
    final boardStates = {for (final p in props) p.id: ref.watch(boardProvider(p.id))};

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tableros',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              const SizedBox(height: 4),
              const Text('Selecciona una propiedad para ver su tablero',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
              const SizedBox(height: 24),
              if (props.isEmpty)
                const Center(child: Text('Sin propiedades asignadas', style: TextStyle(color: Color(0xFF6B7280))))
              else
                _PropertyGrid(properties: props, boardStates: boardStates),
            ],
          ),
        ),
      ),
    );
  }
}

class _PropertyGrid extends StatelessWidget {
  const _PropertyGrid({required this.properties, required this.boardStates});

  final List<Property> properties;
  final Map<String, AsyncValue<BoardState>> boardStates;

  @override
  Widget build(BuildContext context) {
    final cols = Responsive.isMobile(context) ? 2 : 3;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.55,
      ),
      itemCount: properties.length,
      itemBuilder: (_, i) {
        final p = properties[i];
        return _PropertyCard(property: p, boardState: boardStates[p.id]?.valueOrNull);
      },
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.property, this.boardState});

  final Property property;
  final BoardState? boardState;

  @override
  Widget build(BuildContext context) {
    final total = boardState?.totalCards ?? 0;
    final done = boardState?.doneCards ?? 0;
    final hasData = total > 0;

    return GestureDetector(
      // ignore: prefer_interpolation_to_compose_strings
      onTap: () => context.go('/properties/' + property.id + '/board'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            gradient: propertyGradient(property),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0x59000000),
                ),
              ),
              const Positioned(
                top: 12,
                right: 12,
                child: Icon(Icons.star_border_rounded, color: Color(0x99FFFFFF), size: 18),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        property.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.2,
                          shadows: [Shadow(color: Color(0x66000000), blurRadius: 4)],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasData) ...[
                        const SizedBox(height: 2),
                        Text(
                          '$done/$total listas',
                          style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
