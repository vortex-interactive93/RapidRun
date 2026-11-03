import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';

/// High-level states for the stage sheet overlay lifecycle.
/// idle -> singleOffer (one offer) -> multiOffer (>=2) -> activeOrder -> postDelivery -> idle
/// Transitions:
/// - pushOffers: idle => singleOffer or multiOffer
/// - accept: single/multi => activeOrder
/// - decline: singleOffer => idle OR multiOffer => evaluate remaining size
/// - completeActiveOrder: activeOrder => postDelivery (auto timeout => idle)
/// - clear: any => idle
enum StageSheetState {
  idle,
  singleOffer,
  multiOffer,
  activeOrder,
  postDelivery,
}

class StageSheetController extends ChangeNotifier {
  StageSheetState _state = StageSheetState.idle;
  final List<OfferModel> _offers = [];
  OfferModel?
  _activeOrder; // after acceptance becomes the active order reference
  Timer? _postDeliveryTimer;
  DateTime? firstOfferAt;
  bool cinematicPlayed =
      false; // run first-offer entrance only once per session

  StageSheetState get state => _state;
  List<OfferModel> get offers => List.unmodifiable(_offers);
  OfferModel? get activeOrder => _activeOrder;
  bool get hasOffers => _offers.isNotEmpty;

  void pushOffers(List<OfferModel> newOffers) {
    if (newOffers.isEmpty) return;
    // Append unique offers (by id)
    for (final o in newOffers) {
      if (_offers.indexWhere((x) => x.id == o.id) == -1) {
        _offers.add(o);
      }
    }
    firstOfferAt ??= DateTime.now();
    _evaluateOfferState();
  }

  void _evaluateOfferState() {
    if (_activeOrder != null) {
      _transition(StageSheetState.activeOrder);
      return;
    }
    if (_offers.isEmpty) {
      _transition(StageSheetState.idle);
    } else if (_offers.length == 1) {
      _transition(StageSheetState.singleOffer);
    } else {
      _transition(StageSheetState.multiOffer);
    }
  }

  void promote(int index) {
    if (index < 0 || index >= _offers.length) return;
    if (index == 0) return; // already primary
    final o = _offers.removeAt(index);
    _offers.insert(0, o);
    notifyListeners();
  }

  void declinePrimary() {
    if (_offers.isEmpty) return;
    _offers.removeAt(0);
    _evaluateOfferState();
  }

  void acceptPrimary() {
    if (_offers.isEmpty) return;
    _activeOrder = _offers.first;
    _offers.clear();
    _transition(StageSheetState.activeOrder);
  }

  void completeActiveOrder({
    bool showToast = true,
    Duration toastDuration = const Duration(seconds: 4),
  }) {
    if (_activeOrder == null) return;
    _activeOrder = null;
    if (showToast) {
      _transition(StageSheetState.postDelivery);
      _postDeliveryTimer?.cancel();
      _postDeliveryTimer = Timer(toastDuration, () {
        if (_state == StageSheetState.postDelivery) {
          clear();
        }
      });
    } else {
      clear();
    }
  }

  void clear() {
    _offers.clear();
    _activeOrder = null;
    _postDeliveryTimer?.cancel();
    _postDeliveryTimer = null;
    _transition(StageSheetState.idle);
  }

  void resetSession() {
    cinematicPlayed = false;
    clear();
  }

  void _transition(StageSheetState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _postDeliveryTimer?.cancel();
    super.dispose();
  }
}

/// Simple offer model placeholder – adapt fields to match actual incoming offer data.
class OfferModel {
  final String id;
  final double payout; // total estimated payout
  final double distanceMiles; // est miles
  final int itemCount;
  final Duration eta;
  final DateTime expiresAt;
  const OfferModel({
    required this.id,
    required this.payout,
    required this.distanceMiles,
    required this.itemCount,
    required this.eta,
    required this.expiresAt,
  });

  double get payoffIndex => payout / (distanceMiles + (itemCount * 0.15) + 0.4);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
