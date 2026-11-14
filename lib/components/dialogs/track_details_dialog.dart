import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/links/hyper_link.dart';
import 'package:sangeet/extensions/constrains.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/extensions/duration.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/server/sourced_track_provider.dart';

const soulfulBhaktiUrl = "https://www.youtube.com/@SoulfulBhaktiSongsTelugu";

/// The same address without the scheme, which is what the details sheet shows.
const soulfulBhaktiUrlLabel = "youtube.com/@SoulfulBhaktiSongsTelugu";

const _channelName = "Soulful Bhakti Telugu";

class TrackDetailsDialog extends HookConsumerWidget {
  final SangeetFullTrackObject track;
  const TrackDetailsDialog({
    super.key,
    required this.track,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final sourcedTrack = ref.read(sourcedTrackProvider(track));

    final detailsMap = {
      context.l10n.title: track.name,
      context.l10n.duration: sourcedTrack.asData != null
          ? sourcedTrack.asData!.value.info.duration.toHumanReadableString()
          : Duration(milliseconds: track.durationMs).toHumanReadableString(),
      if (track.album.releaseDate != null)
        context.l10n.released: track.album.releaseDate,
    };

    final sourceInfo = sourcedTrack.asData?.value.info;

    return AlertDialog(
      surfaceBlur: 0,
      surfaceOpacity: 1,
      title: Row(
        spacing: 8,
        children: [
          const Icon(SangeetIcons.info),
          Text(
            context.l10n.details,
            style: theme.typography.h4,
          ),
        ],
      ),
      content: SizedBox(
        width: mediaQuery.mdAndUp ? 700 : double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Table(
              columnWidths: const {
                0: FixedTableSize(95),
                1: FixedTableSize(10),
                2: FlexTableSize(),
              },
              theme: const TableTheme(
                backgroundColor: Colors.transparent,
                cellTheme: TableCellTheme(
                  backgroundColor: WidgetStatePropertyAll(Colors.transparent),
                ),
              ),
              rowHeights: const {0: FixedTableSize(40)},
              rows: [
                for (final entry in detailsMap.entries)
                  TableRow(
                    cells: [
                      TableCell(
                        child: Text(
                          entry.key,
                          style: theme.typography.bold,
                        ),
                      ),
                      const TableCell(child: Text(":")),
                      TableCell(
                        child: entry.value is Widget
                            ? entry.value as Widget
                            : (entry.value is String)
                                ? Text(
                                    entry.value as String,
                                    style: theme.typography.normal,
                                  )
                                : const Text(""),
                      ),
                    ],
                  ),
              ],
            ),
            // The source rows are NOT table rows any more.
            //
            // Inside the table they got the third column's leftover width - about
            // a third of the dialog - and a URL was clipped to its first few
            // characters ("https://", later "youtube.com/@SoulfulBha"). As their
            // own full-width rows the address is readable in one line and the
            // label column still lines up with the table above it.
            if (sourceInfo != null) ...[
              const SizedBox(height: 14),
              _DetailLinkRow(
                label: context.l10n.youtube,
                value: soulfulBhaktiUrlLabel,
                url: soulfulBhaktiUrl,
                theme: theme,
              ),
              const SizedBox(height: 8),
              _DetailLinkRow(
                label: context.l10n.channel,
                value: _channelName,
                theme: theme,
              ),
              if (sourcedTrack.asData?.value.url != null) ...[
                const SizedBox(height: 8),
                _DetailLinkRow(
                  label: context.l10n.streamUrl,
                  value: soulfulBhaktiUrlLabel,
                  url: soulfulBhaktiUrl,
                  theme: theme,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// A label/value row that spans the whole dialog, so a long value is never
/// squeezed into a table column.
class _DetailLinkRow extends StatelessWidget {
  final String label;
  final String value;
  final String? url;
  final ThemeData theme;

  const _DetailLinkRow({
    required this.label,
    required this.value,
    required this.theme,
    this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(label, style: theme.typography.bold),
        ),
        const SizedBox(width: 10, child: Text(":")),
        Expanded(
          child: url == null
              ? Text(value, style: theme.typography.normal)
              : Hyperlink(value, url!, style: theme.typography.normal),
        ),
      ],
    );
  }
}
