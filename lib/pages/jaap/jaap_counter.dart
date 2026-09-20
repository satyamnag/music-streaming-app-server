import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/modules/jaap/jaap_counter_chips.dart';
import 'package:sangeet/modules/jaap/jaap_new_counter_dialog.dart';
import 'package:sangeet/modules/jaap/jaap_progress_ring.dart';
import 'package:sangeet/modules/jaap/jaap_streak_strip.dart';
import 'package:sangeet/modules/jaap/jaap_tap_target.dart';
import 'package:sangeet/provider/jaap/jaap_provider.dart';

/// The Jaap Counter. One screen, deliberately:
///
/// The stated goals include "focus the mind" and "reduce mental distraction",
/// so there are no tabs, no charts and no modals during counting. A tap
/// increments immediately in memory; persistence is debounced and never blocks
/// the tap, and no error is ever surfaced while counting.
@RoutePage()
class JaapCounterPage extends HookConsumerWidget {
  const JaapCounterPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final countersAsync = ref.watch(jaapCountersProvider);
    final selectedId = ref.watch(selectedJaapCounterProvider);

    return Scaffold(
      headers: [
        if (kTitlebarVisible) const TitleBar(automaticallyImplyLeading: false),
      ],
      child: countersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (counters) {
          if (counters.isEmpty) {
            return _EmptyState(onCreate: () => _createCounter(context, ref));
          }
          // Fall back to the first counter when nothing is selected or the
          // selection was deleted.
          final active = counters.firstWhere(
            (c) => c.id == selectedId,
            orElse: () => counters.first,
          );
          return _CounterView(
            key: ValueKey(active.id),
            counter: active,
            counters: counters,
          );
        },
      ),
    );
  }
}

/// Shown before the user has created any counter.
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.jaap_new_counter),
          const Gap(12),
          Button.primary(
            onPressed: onCreate,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

/// Creates a counter from the name/target dialog, then selects it.
Future<void> _createCounter(BuildContext context, WidgetRef ref) async {
  final result = await showDialog<({String name, int target})>(
    context: context,
    builder: (_) => const JaapNewCounterDialog(),
  );
  if (result == null) return;
  final id = await ref
      .read(jaapRepositoryProvider)
      .createCounter(name: result.name, dailyTarget: result.target);
  ref.invalidate(jaapCountersProvider);
  ref.read(selectedJaapCounterProvider.notifier).state = id;
}

/// Buffers increments that have not been written to disk yet.
///
/// A tap must never wait on SQLite, so the count is advanced in memory and the
/// unsaved increments accumulate here until the debounce fires. `take()` hands
/// them over for writing; `restore()` puts them back if that write failed, so
/// the next tap retries instead of losing repetitions.
class _PendingIncrements {
  int _count = 0;

  int get count => _count;

  void add() => _count++;

  void clear() => _count = 0;

  void restore(int n) => _count += n;

  int take() {
    final n = _count;
    _count = 0;
    return n;
  }
}

class _CounterView extends HookConsumerWidget {
  final JaapCounter counter;
  final List<JaapCounter> counters;

  const _CounterView({
    required this.counter,
    required this.counters,
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final repo = ref.read(jaapRepositoryProvider);
    final today = DateTime.now();

    // Today's count lives in memory so a tap paints on the next frame. It is
    // seeded from the database once; until then taps are ignored, because
    // counting before the stored value is known would overwrite the day's
    // existing tally.
    final count = useState(0);
    final seeded = useRef(false);
    final pending = useMemoized(_PendingIncrements.new);
    final debounce = useRef<Timer?>(null);

    final streak = useState(0);
    final lifetime = useState(0);
    final week = useState<List<JaapDayStatus>>(const []);

    Future<void> refreshDerived() async {
      final s = await repo.currentStreak(counter.id, today);
      final l = await repo.lifetimeTotal(counter.id);
      final w = await repo.last7Days(counter.id, today);
      if (!context.mounted) return;
      streak.value = s;
      lifetime.value = l;
      week.value = w;
    }

    /// Writes whatever is buffered. Failures are swallowed on purpose: a
    /// transient write error must never interrupt counting, so the unsaved
    /// increments go back into the buffer for the next tap to retry. The spec
    /// forbids any error surface here.
    Future<void> flush() async {
      final n = pending.take();
      if (n <= 0) return;
      try {
        for (var i = 0; i < n; i++) {
          await repo.increment(counter.id, today);
        }
      } catch (_) {
        pending.restore(n);
      }
    }

    void flushSoon() {
      debounce.value?.cancel();
      debounce.value = Timer(const Duration(milliseconds: 400), flush);
    }

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final stored = await repo.todayCount(counter.id, today);
        if (cancelled) return;
        count.value = stored;
        seeded.value = true;
        await refreshDerived();
      }

      load();
      return () {
        cancelled = true;
        // Forced flush: never lose the last taps when the screen is disposed.
        debounce.value?.cancel();
        flush();
      };
    }, [counter.id]);

    final targetReached = count.value >= counter.dailyTarget;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        JaapCounterChips(
          counters: counters,
          selectedId: counter.id,
          onSelect: (id) =>
              ref.read(selectedJaapCounterProvider.notifier).state = id,
          onCreate: () => _createCounter(context, ref),
        ),
        const Gap(24),
        Center(
          child: JaapProgressRing(
            count: count.value,
            target: counter.dailyTarget,
          ),
        ),
        const Gap(24),
        JaapTapTarget(
          targetReached: targetReached,
          onTap: () {
            // Ignore taps until the stored tally has been read.
            if (!seeded.value) return;
            final wasBelowTarget = count.value < counter.dailyTarget;
            count.value += 1;
            pending.add();
            flushSoon();
            // Refresh the derived stats the moment the vow is fulfilled, so
            // the streak and strip update without a manual pull. Fires once.
            if (wasBelowTarget && count.value >= counter.dailyTarget) {
              refreshDerived();
            }
          },
        ),
        const Gap(24),
        Center(
          child: JaapStreakStrip(streak: streak.value, week: week.value),
        ),
        const Gap(16),
        Center(
          child: Text(
            '${context.l10n.jaap_lifetime}: ${lifetime.value}',
            style: TextStyle(color: context.theme.colorScheme.mutedForeground),
          ),
        ),
        const Gap(20),
        Center(
          child: Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              Button.outline(
                onPressed: () async {
                  final edited = await showDialog<({String name, int target})>(
                    context: context,
                    builder: (_) => JaapNewCounterDialog(
                      initialName: counter.name,
                      initialTarget: counter.dailyTarget,
                    ),
                  );
                  if (edited == null) return;
                  await repo.renameCounter(counter.id, edited.name);
                  await repo.setDailyTarget(counter.id, edited.target);
                  if (!context.mounted) return;
                  ref.invalidate(jaapCountersProvider);
                  await refreshDerived();
                },
                child: Text(context.l10n.jaap_rename),
              ),
              Button.outline(
                onPressed: () async {
                  await repo.resetToday(counter.id, today);
                  count.value = 0;
                  pending.clear();
                  if (!context.mounted) return;
                  await refreshDerived();
                },
                child: Text(context.l10n.jaap_reset_today),
              ),
              Button.destructive(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(context.l10n.jaap_delete),
                      content: Text(context.l10n.jaap_delete_confirm),
                      actions: [
                        Button.outline(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: Text(context.l10n.cancel),
                        ),
                        Button.destructive(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          child: Text(context.l10n.jaap_delete),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  // Drop any unsaved taps before the rows disappear, so the
                  // dispose flush cannot recreate them.
                  pending.clear();
                  await repo.deleteCounter(counter.id);
                  if (!context.mounted) return;
                  ref.read(selectedJaapCounterProvider.notifier).state = null;
                  ref.invalidate(jaapCountersProvider);
                },
                child: Text(context.l10n.jaap_delete),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
