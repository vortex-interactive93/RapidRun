/// Shared order lifecycle statuses.
/// Keep values stable; serialized by `name` in Firestore / JSON.
enum OrderStatus {
  pending,
  processing,
  completed,
  failed,
  assigned,
  shopping,
  awaiting_substitution,
  ready_for_delivery,
  enroute,
  delivered,
  canceled,
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
