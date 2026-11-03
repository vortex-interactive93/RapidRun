import 'package:flutter/material.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart'
    hide Order; // avoid type clash
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../services/error_resilience_service.dart';
import '../widgets/order_status_chip.dart';
import '../theme/driver_theme_extension.dart';
import '../presentation/stage/driver_stage_controller.dart';
import 'driver_home_screen.dart';

class ActiveOrderScreen extends StatefulWidget {
  final Order order;
  final VoidCallback? onSignOut;
  const ActiveOrderScreen({super.key, required this.order, this.onSignOut});

  @override
  State<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends State<ActiveOrderScreen> {
  bool _busy = false;
  Order? _order; // local updated order snapshot

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    // Optionally start a listener for live updates to this order.
    FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.order.id)
        .snapshots()
        .listen((snap) {
          if (!snap.exists) return; // could show a message if deleted
          final data = snap.data()!;
          data['id'] = snap.id;
          setState(() {
            _order = Order.fromJson(_normalizeTimestamps(data));
          });
        });
  }

  Map<String, dynamic> _normalizeTimestamps(Map<String, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);
    for (final k in [
      'createdAt',
      'assignedAt',
      'shoppingStartedAt',
      'shoppingCompletedAt',
      'deliveryStartedAt',
      'deliveredAt',
      'canceledAt',
    ]) {
      final v = m[k];
      if (v is Timestamp) m[k] = v.toDate().toIso8601String();
    }
    return m;
  }

  Future<void> _advance(String targetStatus) async {
    if (_busy) return; // guard double taps
    // Optimistic local status preview (reverted on failure)
    final original = _order;
    final originalStatus = _order!.status.name;
    final optimistic =
        _nextForward(originalStatus) == targetStatus ||
        targetStatus == 'canceled';
    if (optimistic) {
      setState(() {
        _order = _order!.copyWith(
          status: OrderStatus.values.firstWhere((e) => e.name == targetStatus),
        );
      });
    }
    setState(() => _busy = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance.collection('orders').doc(_order!.id);
    final driverRef = FirebaseFirestore.instance.collection('drivers').doc(uid);
    String? error;
    final prevStatus = _order!.status;
    try {
      await ErrorResilienceService.instance.runWithRetry(() async {
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final snap = await tx.get(ref);
          if (!snap.exists) throw StateError('Order no longer exists');
          final data = snap.data() as Map<String, dynamic>;
          final current = data['status'] as String;
          final allowed = <String, List<String>>{
            'assigned': ['shopping', 'canceled'],
            'shopping': ['ready_for_delivery', 'canceled'],
            'ready_for_delivery': ['enroute', 'canceled'],
            'enroute': ['delivered', 'canceled'],
          };
          if (!allowed.containsKey(current) ||
              !allowed[current]!.contains(targetStatus)) {
            throw StateError('Invalid transition ($current -> $targetStatus)');
          }
          if (data['driverId'] != uid) {
            throw StateError('You are not the assigned driver');
          }
          final update = <String, dynamic>{'status': targetStatus};
          final tsField = {
            'shopping': 'shoppingStartedAt',
            'ready_for_delivery': 'shoppingCompletedAt',
            'enroute': 'deliveryStartedAt',
            'delivered': 'deliveredAt',
            'canceled': 'canceledAt',
          }[targetStatus];
          if (tsField != null) update[tsField] = FieldValue.serverTimestamp();
          tx.update(ref, update);
          if (targetStatus == 'delivered' || targetStatus == 'canceled') {
            tx.set(driverRef, {'activeOrderId': ''}, SetOptions(merge: true));
          }
        });
      });
    } catch (e) {
      error = e.toString();
    }
    if (mounted) {
      setState(() => _busy = false);
      if (error != null) {
        // Roll back optimistic change if applied
        if (optimistic && mounted) {
          setState(() => _order = original);
        }
        final friendly = ErrorResilienceService.instance.friendly(error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendly),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _advance(targetStatus),
            ),
          ),
        );
      } else {
        // Haptic feedback on successful transition
        try {
          HapticFeedback.lightImpact();
        } catch (_) {}
        // Fire-and-forget analytics event
        FirebaseAnalytics.instance.logEvent(
          name: 'driver_order_transition',
          parameters: {
            'order_id': _order!.id,
            'from': prevStatus,
            'to': targetStatus,
          },
        );
        // Stage Sheet post-delivery toast trigger
        if (targetStatus == 'delivered') {
          _maybeShowPostDelivery();
        }
      }
    }
  }

  // (Removed deprecated _friendlyError method after centralizing resilience.)

  Future<void> _cancel() => _advance('canceled');

  @override
  Widget build(BuildContext context) {
    final order = _order!;
    final status = order.status;
    final forward = _nextForward(status.name);
    final showFab = forward != null && !_busy;
    return Scaffold(
      appBar: AppBar(
        title: Text('Active: ${order.id}'),
        actions: [
          if (widget.onSignOut != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign Out',
              onPressed: widget.onSignOut,
            ),
        ],
      ),
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              heroTag: 'next_step_fab',
              onPressed: () => _advance(forward),
              icon: const Icon(Icons.arrow_forward),
              label: Text(_actionLabelFor(forward)),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ActiveOrderHeader(order: order),
          const SizedBox(height: 24),
          Text('Items (${order.items.length})'),
          const SizedBox(height: 8),
          ...order.items.map(
            (i) => ListTile(
              dense: true,
              title: Text('${i.quantity} x ${i.name}'),
              subtitle: Text('Each ${i.unitPrice.toStringAsFixed(2)}'),
              trailing: const Icon(
                Icons.check_box_outline_blank,
                size: 20,
              ), // future interactive state
            ),
          ),
          const SizedBox(height: 24),
          // Inline buttons suppressed if FAB is active for a single forward path
          if (!showFab) ...[
            if (status == 'assigned') ...[
              FilledButton(
                onPressed: _busy ? null : () => _advance('shopping'),
                child: const Text('Start Shopping'),
              ),
            ] else if (status == 'shopping') ...[
              FilledButton(
                onPressed: _busy ? null : () => _advance('ready_for_delivery'),
                child: const Text('Complete Shopping'),
              ),
            ] else if (status == 'ready_for_delivery') ...[
              FilledButton(
                onPressed: _busy ? null : () => _advance('enroute'),
                child: const Text('Start Delivery'),
              ),
            ] else if (status == 'enroute') ...[
              FilledButton(
                onPressed: _busy ? null : () => _advance('delivered'),
                child: const Text('Mark Delivered'),
              ),
            ] else ...[
              const Text('No further actions.'),
            ],
          ],
          const SizedBox(height: 12),
          if ([
            'assigned',
            'shopping',
            'ready_for_delivery',
            'enroute',
          ].contains(status))
            TextButton.icon(
              onPressed: _busy ? null : _cancel,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel Order'),
            ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ),
    );
  }

  String _actionLabelFor(String forward) {
    switch (forward) {
      case 'shopping':
        return 'Start Shopping';
      case 'ready_for_delivery':
        return 'Complete Shopping';
      case 'enroute':
        return 'Start Delivery';
      case 'delivered':
        return 'Mark Delivered';
      default:
        return 'Advance';
    }
  }

  String? _nextForward(String current) {
    switch (current) {
      case 'assigned':
        return 'shopping';
      case 'shopping':
        return 'ready_for_delivery';
      case 'ready_for_delivery':
        return 'enroute';
      case 'enroute':
        return 'delivered';
      default:
        return null;
    }
  }
}

final GlobalKey<NavigatorState> _driverNavKey = GlobalKey<NavigatorState>();

void _maybeShowPostDelivery() {
  // Attempt to retrieve a DriverStageController from the root navigator context.
  final ctx = _driverNavKey.currentContext;
  if (ctx == null) return;
  // Traverse element tree to find any inherited element holding a DriverStageSheet controller.
  // Since we don't have a provider yet, we rely on finding the nearest stateful element of type DriverHomeScreen.
  // (Future: move to InheritedWidget/Provider.)
  try {
    // Use global registration hook (set in home screen) instead of reflection.
    DriverStageController? global =
        DriverStageControllerRegistry.instance.controller;
    if (global != null) {
      global.showPostDeliveryToast();
    }
  } catch (_) {}
}

/// Simple global registry until we introduce Provider or Riverpod.
class DriverStageControllerRegistry {
  DriverStageController? controller;
  DriverStageControllerRegistry._();
  static final instance = DriverStageControllerRegistry._();
}

class _ActiveOrderHeader extends StatelessWidget {
  final Order order;
  const _ActiveOrderHeader({required this.order});

  List<_StepMeta> get _steps => const [
    _StepMeta('assigned', 'Assigned'),
    _StepMeta('shopping', 'Shopping'),
    _StepMeta('ready_for_delivery', 'Ready'),
    _StepMeta('enroute', 'En Route'),
    _StepMeta('delivered', 'Done'),
  ];

  int _currentIndex() {
    final idx = _steps.indexWhere((s) => s.key == order.status.name);
    if (idx == -1) return 0;
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = _currentIndex();
    final phaseLine = _buildPhaseDurations();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Order #${order.id}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OrderStatusChip(status: order.status, elevated: true),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${order.items.length} items • ${order.total.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ProgressTimeline(steps: _steps, current: current),
            if (phaseLine != null) ...[const SizedBox(height: 10), phaseLine],
          ],
        ),
      ),
    );
  }

  Widget? _buildPhaseDurations() {
    // Derive timestamps from order (ISO strings) to DateTimes.
    DateTime? _parse(String? iso) =>
        iso == null || iso.isEmpty ? null : DateTime.tryParse(iso);
    final created = _parse(order.createdAt.toIso8601String());
    final shopStart = _parse(order.shoppingStartedAt?.toIso8601String());
    final shopEnd = _parse(order.shoppingCompletedAt?.toIso8601String());
    final deliveryStart = _parse(order.deliveryStartedAt?.toIso8601String());
    final delivered = _parse(order.deliveredAt?.toIso8601String());
    // If we don't even have assigned or created bail.
    if (created == null) return null;

    String fmt(Duration d) {
      if (d.inMinutes < 1) return '${d.inSeconds}s';
      if (d.inMinutes < 60) return '${d.inMinutes}m';
      return '${d.inHours}h';
    }

    final now = DateTime.now();
    Duration? shoppingDur;
    if (shopStart != null) {
      shoppingDur = (shopEnd ?? now).difference(shopStart);
    }
    Duration? deliveryDur;
    if (deliveryStart != null) {
      deliveryDur = (delivered ?? now).difference(deliveryStart);
    }
    final totalDur = (delivered ?? now).difference(created);

    final parts = <String>[];
    if (shoppingDur != null) parts.add('Shopping ${fmt(shoppingDur)}');
    if (deliveryDur != null) parts.add('Route ${fmt(deliveryDur)}');
    parts.add('Total ${fmt(totalDur)}');
    return Text(
      parts.join(' • '),
      style: const TextStyle(fontSize: 11, color: Colors.white70),
    );
  }
}

class _StepMeta {
  final String key;
  final String label;
  const _StepMeta(this.key, this.label);
}

class _ProgressTimeline extends StatelessWidget {
  final List<_StepMeta> steps;
  final int current;
  const _ProgressTimeline({required this.steps, required this.current});

  @override
  Widget build(BuildContext context) {
    final dt =
        Theme.of(context).extension<DriverTheme>() ?? DriverTheme.fallback;
    Color colorFor(String key) {
      switch (key) {
        case 'assigned':
          return dt.assigned;
        case 'shopping':
          return dt.shopping;
        case 'ready_for_delivery':
          return dt.readyForDelivery;
        case 'enroute':
          return dt.enroute;
        case 'delivered':
          return dt.delivered;
        default:
          return dt.pending;
      }
    }

    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _TimelineDot(
            label: steps[i].label,
            index: i,
            active: i <= current,
            isLast: i == steps.length - 1,
            color: colorFor(steps[i].key),
          ),
        ],
      ],
    );
  }
}

class _TimelineDot extends StatelessWidget {
  final String label;
  final int index;
  final bool active;
  final bool isLast;
  final Color color;
  const _TimelineDot({
    required this.label,
    required this.index,
    required this.active,
    required this.isLast,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final base = active ? color : Colors.grey.shade700;
    return Expanded(
      child: Column(
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                width: active ? 16 : 14,
                height: active ? 16 : 14,
                decoration: BoxDecoration(
                  color: base,
                  shape: BoxShape.circle,
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: base.withOpacity(.50),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: active
                            ? [base, base.withOpacity(.20)]
                            : [Colors.grey.shade700, Colors.grey.shade800],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? Colors.white : Colors.white70,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
