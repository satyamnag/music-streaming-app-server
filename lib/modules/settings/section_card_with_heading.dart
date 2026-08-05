import 'package:flutter/material.dart' show ListTileTheme, ListTileThemeData;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Theme, ThemeData;
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

class SectionCardWithHeading extends StatelessWidget {
  final String heading;
  final List<Widget> children;
  const SectionCardWithHeading({
    super.key,
    required this.heading,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Center(
                child: Text(
                  heading,
                  textAlign: TextAlign.center,
                  style: context.theme.typography.large.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.theme.colorScheme.foreground,
                  ),
                ),
              ),
            ),
            ListTileTheme(
              data: ListTileThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: context.theme.borderRadiusLg,
                  side: BorderSide(
                    color: context.theme.colorScheme.border,
                    width: .5,
                  ),
                ),
                textColor: context.theme.colorScheme.foreground,
                iconColor: context.theme.colorScheme.foreground,
                selectedColor: context.theme.colorScheme.accent,
                subtitleTextStyle: context.theme.typography.xSmall,
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: context.theme.borderRadiusLg,
                  color: context.theme.colorScheme.muted.withValues(alpha: 0.35),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ).gap(8.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
