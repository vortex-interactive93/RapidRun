/// Order lifecycle statuses.
/// Existing persisted values (pending, processing, completed, failed) retained for backward compatibility.
/// New granular states appended; decoding matches by name so old records remain valid.
enum OrderStatus {
  pending, // created, awaiting internal processing / driver assignment
  processing, // legacy in-progress state (fallback)
  completed, // legacy completed state (kept for backward compat)
  failed, // payment or creation failure
  assigned, // driver assigned but not yet started shopping
  shopping, // driver actively shopping / collecting items
  awaiting_substitution, // waiting for customer approval on a substitution
  ready_for_delivery, // shopping done, ready to head out
  enroute, // driver on the way to customer
  delivered, // delivered to customer (preferred over completed going forward)
  canceled, // canceled by customer or system
}

String orderStatusLabel(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return 'Pending';
    case OrderStatus.processing:
      return 'Processing';
    case OrderStatus.completed:
      return 'Completed';
    case OrderStatus.failed:
      return 'Failed';
    case OrderStatus.assigned:
      return 'Assigned';
    case OrderStatus.shopping:
      return 'Shopping';
    case OrderStatus.awaiting_substitution:
      return 'Awaiting Substitution';
    case OrderStatus.ready_for_delivery:
      return 'Ready for Delivery';
    case OrderStatus.enroute:
      return 'En Route';
    case OrderStatus.delivered:
      return 'Delivered';
    case OrderStatus.canceled:
      return 'Canceled';
  }
}
