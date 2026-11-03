import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrun_driver/presentation/stage/driver_stage_controller.dart';
import 'package:rapidrun_driver/presentation/home/incoming_offer_overlay.dart';

IncomingOfferData _makeOffer(String id) => IncomingOfferData(
  id: id,
  store: 'Demo Store',
  dropoffArea: 'Zone A',
  pay: 12.34,
  distanceMiles: 4.2,
  eta: const Duration(minutes: 15),
  expiresIn: const Duration(seconds: 30),
);

void main() {
  group('DriverStageController', () {
    test('enqueue -> accept transitions to activeOrder and clears queue', () {
      final c = DriverStageController();
      expect(c.state.stage, DriverStage.idle);
      c.enqueueOffer(_makeOffer('o1'));
      expect(c.state.stage, DriverStage.singleOffer);
      expect(c.state.activeOffer?.id, 'o1');
      c.acceptActive();
      expect(c.state.stage, DriverStage.activeOrder);
      expect(c.state.offers.isEmpty, true);
      expect(c.state.activeOffer, isNull);
    });

    test('multi-offer cycleForward rotates active index', () {
      final c = DriverStageController();
      c.enqueueOffers([_makeOffer('o1'), _makeOffer('o2'), _makeOffer('o3')]);
      expect(c.state.stage, DriverStage.multiOffer);
      expect(c.state.activeOffer?.id, 'o1');
      c.cycleForward();
      expect(c.state.activeOffer?.id, 'o2');
      c.cycleForward();
      expect(c.state.activeOffer?.id, 'o3');
      c.cycleForward();
      expect(c.state.activeOffer?.id, 'o1');
    });

    test('declineActive removes offer and updates stage', () {
      final c = DriverStageController();
      c.enqueueOffers([_makeOffer('o1'), _makeOffer('o2')]);
      expect(c.state.stage, DriverStage.multiOffer);
      c.declineActive();
      expect(c.state.offers.length, 1);
      expect(c.state.activeOffer?.id, 'o2');
      expect(c.state.stage, DriverStage.singleOffer);
    });
  });
}
