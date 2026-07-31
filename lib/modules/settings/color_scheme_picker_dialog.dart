import 'package:collection/collection.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/modules/settings/bhakti_color_scheme.dart';

import 'package:sangeet/provider/user_preferences/user_preferences_provider.dart';

class SangeetColor extends Color {
  final String name;

  const SangeetColor(super.color, {required this.name});

  const SangeetColor.from(super.value, {required this.name});

  factory SangeetColor.fromString(String string) {
    final slices = string.split(":");
    return SangeetColor(int.parse(slices.last), name: slices.first);
  }

  @override
  String toString() {
    return "$name:${toARGB32()}";
  }
}

final Set<SangeetColor> colorsMap = {
  SangeetColor(Colors.slate.value, name: "slate"),
  SangeetColor(Colors.gray.value, name: "gray"),
  SangeetColor(Colors.zinc.value, name: "zinc"),
  SangeetColor(Colors.neutral.value, name: "neutral"),
  SangeetColor(Colors.stone.value, name: "stone"),
  SangeetColor(Colors.red.value, name: "red"),
  SangeetColor(Colors.orange.value, name: "orange"),
  SangeetColor(Colors.yellow.value, name: "yellow"),
  SangeetColor(Colors.green.value, name: "green"),
  SangeetColor(Colors.blue.value, name: "blue"),
  SangeetColor(Colors.violet.value, name: "violet"),
  SangeetColor(Colors.rose.value, name: "rose"),
  SangeetColor(0xFF520101, name: "maroon"),
};

final colorSchemeMap = {
  "slate": LegacyColorSchemes.slate,
  "gray": LegacyColorSchemes.gray,
  "zinc": LegacyColorSchemes.zinc,
  "neutral": LegacyColorSchemes.neutral,
  "stone": LegacyColorSchemes.stone,
  "red": LegacyColorSchemes.red,
  "orange": LegacyColorSchemes.orange,
  "yellow": LegacyColorSchemes.yellow,
  "green": LegacyColorSchemes.green,
  "blue": LegacyColorSchemes.blue,
  "violet": LegacyColorSchemes.violet,
  "rose": LegacyColorSchemes.rose,
  "maroon": BhaktiColorSchemes.maroon,
};

class ColorSchemePickerDialog extends HookConsumerWidget {
  const ColorSchemePickerDialog({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final preferences = ref.watch(userPreferencesProvider);
    final preferencesNotifier = ref.watch(userPreferencesProvider.notifier);

    final scheme = preferences.accentColorScheme;
    final active = useState<String?>(
      colorsMap.firstWhereOrNull(
        (element) {
          return scheme.name == element.name;
        },
      )?.name,
    );

    return AlertDialog(
      title: Text(
        context.l10n.pick_color_scheme,
        style: TextStyle(color: context.theme.colorScheme.foreground),
      ).large(),
      actions: [
        Button.outline(
          child: Text(context.l10n.cancel),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        Button.primary(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(context.l10n.save),
        ),
      ],
      content: SizedBox(
        height: 200,
        width: 400,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colorsMap.map(
            (color) {
              return ColorChip(
                name: color.name,
                color: color,
                isActive: color.name == active.value,
                onPressed: () {
                  active.value = color.name;
                  preferencesNotifier.setAccentColorScheme(
                    colorsMap.firstWhere(
                      (element) {
                        return element.name == color.name;
                      },
                    ),
                  );
                },
              );
            },
          ).toList(),
        ),
      ),
    );
  }
}

class ColorChip extends StatelessWidget {
  final String name;
  final Color color;
  final bool isActive;
  final VoidCallback onPressed;
  const ColorChip({
    super.key,
    required this.name,
    required this.color,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      leading: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: onPressed,
      style: isActive ? ButtonVariance.primary : ButtonVariance.outline,
      child: Text(name),
    );
  }
}
