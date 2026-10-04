// Renders a contact sheet of every Featured Playlist chip glyph to a PNG.
//
// Kept as a tool (not a test) because it writes a file and is meant to be
// LOOKED AT: a painter that runs without error can still draw the wrong shape,
// and reviewing the sheet is how the Om and Ganesha glyphs were caught being
// unrecognisable. The automated shape checks live in test/glyph_painter_test.dart.
//
// Usage:
//   flutter test tool/render_glyph_sheet.dart
// then open the printed path.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' as material;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/modules/home/sections/featured_playlist_chips.dart';

/// Every glyph the admin dropdown and the built-in chips can ask for, plus an
/// unknown name and an empty one to show the fallback.
const _names = <String>[
  'temple',
  'flute',
  'ganesha',
  'bow',
  'lotus',
  'om',
  'music',
  'nope',
  '',
];

void main() {
  testWidgets('render the glyph contact sheet', (tester) async {
    tester.view.physicalSize = const material.Size(1200, 220);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      material.MaterialApp(
        debugShowCheckedModeBanner: false,
        home: material.Directionality(
          textDirection: material.TextDirection.ltr,
          child: material.ColoredBox(
            color: const material.Color(0xFFFFFFFF),
            child: material.Center(
              child: material.RepaintBoundary(
                child: material.Row(
                  mainAxisSize: material.MainAxisSize.min,
                  children: [
                    for (final name in _names)
                      material.Padding(
                        padding: const material.EdgeInsets.symmetric(horizontal: 8),
                        child: material.Column(
                          mainAxisSize: material.MainAxisSize.min,
                          children: [
                            material.Container(
                              width: 84,
                              height: 84,
                              decoration: const material.BoxDecoration(
                                shape: material.BoxShape.circle,
                                gradient: material.LinearGradient(
                                  begin: material.Alignment.topLeft,
                                  end: material.Alignment.bottomRight,
                                  colors: [
                                    material.Color(0xFFEF4444),
                                    material.Color(0xFFB91C1C),
                                  ],
                                ),
                              ),
                              child: material.Center(
                                child: material.CustomPaint(
                                  size: const material.Size(42, 42),
                                  painter: FeaturedChipGlyphPainter(
                                    name: name,
                                    color: const material.Color(0xFFFFFFFF),
                                  ),
                                ),
                              ),
                            ),
                            material.SizedBox(height: 6),
                            material.Text(
                              name.isEmpty ? '(empty)' : name,
                              style: const material.TextStyle(
                                fontSize: 11,
                                color: material.Color(0xFF111111),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(material.RepaintBoundary).first,
    );
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(bytes, isNotNull);

    final out = File(r'D:\Soulful Bhakti\_temp\web-verify\glyph-sheet.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('glyph sheet -> ${out.path} (${bytes.lengthInBytes} bytes)');
  });
}
