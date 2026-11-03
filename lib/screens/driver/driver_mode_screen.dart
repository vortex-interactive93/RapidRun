import 'package:flutter/material.dart';
import '../../services/driver_service.dart';
import '../../services/orders_service.dart';
import '../../models/order.dart';
import '../../models/order_status.dart';
import '../../theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/orders_provider.dart';
import '../../providers/driver_provider.dart';
import '../../services/substitution_service.dart';
import '../../models/substitution_request.dart';

/// Prototype driver mode screen (local only, no auth role yet).
class DriverModeScreen extends ConsumerStatefulWidget {
  final String driverId; // pass current user uid (or test id)
  final String name;
  const DriverModeScreen({
    super.key,
    required this.driverId,
    required this.name,
  });

  @override
  @override
  ConsumerState<DriverModeScreen> createState() => _DriverModeScreenState();
}

class _DriverModeScreenState extends ConsumerState<DriverModeScreen> {
  bool _loading = true;
  bool _online = false;
  String? _activeOrderId;
  List<Order> _pending = [];
  bool _initialized = false;

  Future<void> _load() async {
    setState(() => _loading = true);
    await DriverService.instance.bootstrap();
    await OrdersService.instance.bootstrap();
    await DriverService.instance.upsertDriver(
      widget.driverId,
      name: widget.name,
    );
    final profile = DriverService.instance.getById(widget.driverId);
    _online = profile?.online ?? false;
    _activeOrderId = profile?.activeOrderId;
    _pending = OrdersService.instance.orders
        .where(
          (o) =>
              o.status == OrderStatus.pending ||
              o.status == OrderStatus.assigned,
        )
        .toList();
    setState(() => _loading = false);
    if (!_initialized) {
      DriverService.instance.addListener(_onDriverChanged);
      OrdersService.instance.addListener(_onOrdersChanged);
      _initialized = true;
    }
  }

  void _onDriverChanged() {
    final profile = DriverService.instance.getById(widget.driverId);
    if (!mounted) return;
    if (profile == null) return;
    setState(() {
      _online = profile.online;
      _activeOrderId = profile.activeOrderId == '_none'
          ? null
          : profile.activeOrderId;
    });
  }

  void _onOrdersChanged() {
    if (!mounted) return;
    final orders = OrdersService.instance.orders;
    setState(() {
      _pending = orders
          .where(
            (o) =>
                o.status == OrderStatus.pending ||
                o.status == OrderStatus.assigned,
          )
          .toList();
      if (_activeOrderId != null) {
        final activeIdx = orders.indexWhere((o) => o.id == _activeOrderId);
        if (activeIdx == -1) {
          _activeOrderId = null;
        } else {
          final active = orders[activeIdx];
          if (active.status == OrderStatus.delivered ||
              active.status == OrderStatus.canceled) {
            _activeOrderId = null;
          }
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_initialized) {
      DriverService.instance.removeListener(_onDriverChanged);
      OrdersService.instance.removeListener(_onOrdersChanged);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersSvc = ref.watch(ordersProvider);
    final driverSvc = ref.watch(driversProvider);
    final profile = driverSvc.getById(widget.driverId);
    final activeOrder = profile?.activeOrderId == null
        ? null
        : ordersSvc.orders.firstWhere(
            (o) => o.id == profile!.activeOrderId,
            orElse: () => ordersSvc.orders.isEmpty
                ? null as dynamic
                : ordersSvc.orders.first,
          );
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Mode')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Switch(
                        value: _online,
                        onChanged: (v) async {
                          await DriverService.instance.setOnline(
                            widget.driverId,
                            v,
                          );
                          setState(() => _online = v);
                        },
                      ),
                      Text(_online ? 'Online' : 'Offline'),
                      const Spacer(),
                      if (profile?.lastPingAt != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            '${profile!.lastLat?.toStringAsFixed(3)}/${profile.lastLng?.toStringAsFixed(3)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      if (_activeOrderId != null)
                        ElevatedButton(
                          onPressed: () async {
                            await OrdersService.instance.markDelivered(
                              _activeOrderId!,
                            );
                            await DriverService.instance.clearOrder(
                              widget.driverId,
                            );
                            setState(() => _activeOrderId = null);
                            _load();
                          },
                          child: const Text('Mark Delivered'),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start GPS Sim'),
                        onPressed: () => DriverService.instance
                            .startHeartbeatSimulation(widget.driverId),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                        onPressed: () => DriverService.instance
                            .stopHeartbeatSimulation(widget.driverId),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (activeOrder != null)
                    _ActiveOrderCard(order: activeOrder)
                  else
                    Expanded(
                      child: _pending.isEmpty
                          ? const Center(child: Text('No pending orders'))
                          : ListView.builder(
                              itemCount: _pending.length,
                              itemBuilder: (_, i) {
                                final o = _pending[i];
                                return Card(
                                  child: ListTile(
                                    title: Text(
                                      'Order #${o.id} (${o.items.length} items)',
                                    ),
                                    subtitle: Text(o.status.name),
                                    trailing: ElevatedButton(
                                      onPressed:
                                          !_online || _activeOrderId != null
                                          ? null
                                          : () async {
                                              await OrdersService.instance
                                                  .markAssigned(
                                                    o.id,
                                                    widget.driverId,
                                                  );
                                              await DriverService.instance
                                                  .assignOrder(
                                                    widget.driverId,
                                                    o.id,
                                                  );
                                            },
                                      child: const Text('Accept'),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  final Order order;
  const _ActiveOrderCard({required this.order});
  @override
  Widget build(BuildContext context) {
    final subs = SubstitutionService.instance.byOrder(order.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active Order #${order.id}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${order.items.length} items • Total ${order.total.toStringAsFixed(2)}',
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              children: [
                _step(
                  order.status == OrderStatus.assigned ||
                      order.status == OrderStatus.shopping,
                  'Shopping',
                ),
                _step(
                  order.status == OrderStatus.ready_for_delivery ||
                      order.status == OrderStatus.enroute,
                  'Ready',
                ),
                _step(order.status == OrderStatus.enroute, 'En Route'),
                _step(order.status == OrderStatus.delivered, 'Delivered'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                ElevatedButton(
                  onPressed: order.status == OrderStatus.assigned
                      ? () async {
                          await OrdersService.instance.markShoppingStarted(
                            order.id,
                          );
                        }
                      : null,
                  child: const Text('Start Shopping'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: order.status == OrderStatus.shopping
                      ? () async {
                          await OrdersService.instance.markShoppingCompleted(
                            order.id,
                          );
                        }
                      : null,
                  child: const Text('Finish Shopping'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: order.status == OrderStatus.ready_for_delivery
                      ? () async {
                          await OrdersService.instance.markEnRoute(order.id);
                        }
                      : null,
                  child: const Text('Start Delivery'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: order.status == OrderStatus.enroute
                      ? () async {
                          await OrdersService.instance.markDelivered(order.id);
                        }
                      : null,
                  child: const Text('Deliver'),
                ),
              ],
            ),
            if (order.status == OrderStatus.shopping) ...[
              const SizedBox(height: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: () async {
                  final firstItem = order.items.first;
                  await SubstitutionService.instance.create(
                    orderId: order.id,
                    productId: firstItem.productId,
                    originalName: firstItem.name,
                    proposedName: '${firstItem.name} (Alt)',
                    proposedProductId: null,
                    proposedPrice: null,
                  );
                },
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Request Substitution (first item)'),
              ),
            ],
            if (subs.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Substitution Requests (${subs.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              for (final r in subs)
                ListTile(
                  dense: true,
                  title: Text(r.originalName),
                  subtitle: Text('→ ${r.proposedName} • ${r.status.name}'),
                  trailing: r.status == SubstitutionRequestStatus.pending
                      ? Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                              onPressed: () =>
                                  SubstitutionService.instance.decide(
                                    r.id,
                                    SubstitutionRequestStatus.approved,
                                  ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () =>
                                  SubstitutionService.instance.decide(
                                    r.id,
                                    SubstitutionRequestStatus.rejected,
                                  ),
                            ),
                          ],
                        )
                      : null,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _step(bool active, String label) {
    return Chip(
      label: Text(label),
      backgroundColor: active ? Colors.green : Colors.grey.shade700,
    );
  }
}
