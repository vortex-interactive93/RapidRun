import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/substitution_service.dart';
import '../models/substitution_request.dart';

final substitutionProvider = ChangeNotifierProvider<SubstitutionService>((ref) {
  final svc = SubstitutionService.instance;
  svc.bootstrap();
  return svc;
});

List<SubstitutionRequest> useSubstitutionsForOrder(
  WidgetRef ref,
  String orderId,
) {
  final svc = ref.watch(substitutionProvider);
  return svc.byOrder(orderId);
}
