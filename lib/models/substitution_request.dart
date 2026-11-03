import 'dart:convert';

/// Status of a substitution request originating during shopping.
enum SubstitutionRequestStatus { pending, approved, rejected }

class SubstitutionRequest {
  final String id; // unique id
  final String orderId;
  final String productId; // original product
  final String originalName;
  final String proposedName; // proposed alt product name (placeholder text)
  final String? proposedProductId; // potential future actual catalog id
  final double? proposedPrice; // snapshot price for alternative
  final DateTime createdAt;
  final SubstitutionRequestStatus status;
  final DateTime? decidedAt;
  final String? decisionNote;

  const SubstitutionRequest({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.originalName,
    required this.proposedName,
    this.proposedProductId,
    this.proposedPrice,
    required this.createdAt,
    this.status = SubstitutionRequestStatus.pending,
    this.decidedAt,
    this.decisionNote,
  });

  SubstitutionRequest copyWith({
    SubstitutionRequestStatus? status,
    DateTime? decidedAt,
    String? decisionNote,
    String? proposedProductId,
    double? proposedPrice,
  }) => SubstitutionRequest(
    id: id,
    orderId: orderId,
    productId: productId,
    originalName: originalName,
    proposedName: proposedName,
    proposedProductId: proposedProductId ?? this.proposedProductId,
    proposedPrice: proposedPrice ?? this.proposedPrice,
    createdAt: createdAt,
    status: status ?? this.status,
    decidedAt: decidedAt ?? this.decidedAt,
    decisionNote: decisionNote ?? this.decisionNote,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    'productId': productId,
    'originalName': originalName,
    'proposedName': proposedName,
    if (proposedProductId != null) 'proposedProductId': proposedProductId,
    if (proposedPrice != null) 'proposedPrice': proposedPrice,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    if (decidedAt != null) 'decidedAt': decidedAt!.toIso8601String(),
    if (decisionNote != null) 'decisionNote': decisionNote,
  };

  static SubstitutionRequest fromJson(Map<String, dynamic> j) =>
      SubstitutionRequest(
        id: j['id'] as String,
        orderId: j['orderId'] as String,
        productId: j['productId'] as String,
        originalName: j['originalName'] as String? ?? 'Original',
        proposedName: j['proposedName'] as String? ?? 'Proposed',
        proposedProductId: j['proposedProductId'] as String?,
        proposedPrice: (j['proposedPrice'] as num?)?.toDouble(),
        createdAt: DateTime.parse(j['createdAt'] as String),
        status: SubstitutionRequestStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => SubstitutionRequestStatus.pending,
        ),
        decidedAt: j['decidedAt'] != null
            ? DateTime.tryParse(j['decidedAt'] as String)
            : null,
        decisionNote: j['decisionNote'] as String?,
      );

  static String encodeList(List<SubstitutionRequest> list) =>
      json.encode(list.map((e) => e.toJson()).toList());
  static List<SubstitutionRequest> decodeList(String raw) {
    if (raw.isEmpty) return [];
    final list = json.decode(raw) as List;
    return list
        .map((e) => SubstitutionRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
