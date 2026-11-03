import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../presentation/home/incoming_offer_overlay.dart';

/// Driver UI high-level stages driving the Stage Sheet.
/// idle: no offers, not in active order.
/// singleOffer: exactly one offer (cinematic entrance eligible).
/// multiOffer: 2+ offers stacked.
/// activeOrder: driver has an accepted order (basic placeholder phase 1).
/// postDelivery: transient toast-like celebration after completing delivery.
enum DriverStage { idle, singleOffer, multiOffer, activeOrder, postDelivery }

class DriverStageState {
  final DriverStage stage;
  final List<IncomingOfferData> offers; // queue
  final int activeIndex; // index in offers currently primary (0 if single)
  final bool firstCinematicPlayed; // prevents re-running first-offer entrance
  final DateTime? postDeliveryShownAt;
  const DriverStageState({
    required this.stage,
    required this.offers,
    required this.activeIndex,
    required this.firstCinematicPlayed,
    required this.postDeliveryShownAt,
  });
  IncomingOfferData? get activeOffer =>
      offers.isEmpty ? null : offers[activeIndex.clamp(0, offers.length - 1)];
  DriverStageState copyWith({
    DriverStage? stage,
    List<IncomingOfferData>? offers,
    int? activeIndex,
    bool? firstCinematicPlayed,
    DateTime? postDeliveryShownAt,
  }) => DriverStageState(
    stage: stage ?? this.stage,
    offers: offers ?? this.offers,
    activeIndex: activeIndex ?? this.activeIndex,
    firstCinematicPlayed: firstCinematicPlayed ?? this.firstCinematicPlayed,
    postDeliveryShownAt: postDeliveryShownAt ?? this.postDeliveryShownAt,
  );
}

/// Controller orchestrating stage transitions & offer queue lifecyle.
class DriverStageController extends ChangeNotifier {
  DriverStageState _state = const DriverStageState(
    stage: DriverStage.idle,
    offers: [],
    activeIndex: 0,
    firstCinematicPlayed: false,
    postDeliveryShownAt: null,
  );
  DriverStageState get state => _state;

  Timer? _postDeliveryTimer;

  void dispose() {
    _postDeliveryTimer?.cancel();
    super.dispose();
  }

  // ---- Offer Queue Management ----
  void enqueueOffer(IncomingOfferData offer) {
    final newOffers = [..._state.offers, offer];
    _updateForOffers(newOffers, newlyAdded: true);
  }

  void enqueueOffers(Iterable<IncomingOfferData> offers) {
    final newOffers = [..._state.offers, ...offers];
    _updateForOffers(newOffers, newlyAdded: true);
  }

  void declineActive() {
    if (_state.offers.isEmpty) return;
    final idx = _state.activeIndex;
    final newOffers = [..._state.offers]..removeAt(idx);
    final newIndex = newOffers.isEmpty
        ? 0
        : (idx.clamp(0, newOffers.length - 1));
    _updateForOffers(newOffers, activeIndex: newIndex);
  }

  void acceptActive() {
    if (_state.offers.isEmpty) return;
    // Phase 1: simply clear queue & move to activeOrder
    _state = _state.copyWith(
      offers: const [],
      activeIndex: 0,
      stage: DriverStage.activeOrder,
    );
    notifyListeners();
  }

  void expireActive() {
    declineActive();
  }

  void cycleForward() {
    if (_state.offers.length < 2) return;
    final next = (_state.activeIndex + 1) % _state.offers.length;
    _state = _state.copyWith(activeIndex: next);
    notifyListeners();
  }

  // Called when an order is fully delivered to show toast stage.
  void showPostDeliveryToast({Duration duration = const Duration(seconds: 4)}) {
    _postDeliveryTimer?.cancel();
    _state = _state.copyWith(
      stage: DriverStage.postDelivery,
      postDeliveryShownAt: DateTime.now(),
    );
    notifyListeners();
    _postDeliveryTimer = Timer(duration, () {
      // Return to offers state if offers exist else idle
      if (_state.offers.isEmpty) {
        _state = _state.copyWith(stage: DriverStage.idle);
      } else {
        _state = _state.copyWith(
          stage: _state.offers.length == 1
              ? DriverStage.singleOffer
              : DriverStage.multiOffer,
        );
      }
      notifyListeners();
    });
  }

  void markCinematicPlayed() {
    if (_state.firstCinematicPlayed) return;
    _state = _state.copyWith(firstCinematicPlayed: true);
    notifyListeners();
  }

  // ---- Internal helpers ----
  void _updateForOffers(
    List<IncomingOfferData> newOffers, {
    bool newlyAdded = false,
    int? activeIndex,
  }) {
    DriverStage newStage;
    if (newOffers.isEmpty) {
      newStage = DriverStage.idle;
    } else if (newOffers.length == 1) {
      newStage = DriverStage.singleOffer;
    } else {
      newStage = DriverStage.multiOffer;
    }
    final cinematicAlready = _state.firstCinematicPlayed;
    _state = _state.copyWith(
      offers: newOffers,
      activeIndex: activeIndex ?? 0,
      stage: newStage,
      // Keep flag false until animation actually runs; leave true once marked.
      firstCinematicPlayed: cinematicAlready,
    );
    notifyListeners();
  }
}
