import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrun/services/product_catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ProductCatalogService loads assets and exposes products', () async {
    final svc = ProductCatalogService.instance;
    await svc.ensureLoaded();
    expect(svc.isLoaded, true);
    expect(svc.count, greaterThan(0));
    // Spot check retrieval of first id
    final first = svc.all().first;
    expect(first.id.isNotEmpty, true);
  });
}
