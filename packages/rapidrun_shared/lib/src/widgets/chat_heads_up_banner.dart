// File: packages/rapidrun_shared/lib/src/widgets/chat_heads_up_banner.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat/order_chat_sheet.dart';

class ChatNotificationListenerWrapper extends StatefulWidget {
  final Widget child;
  final String orderId;
  final String currentSenderId; // 'cust_thomas_davis' or driver ID
  final String currentSenderName;
  final bool isDriver;
  final String recipientLabel;

  const ChatNotificationListenerWrapper({
    super.key,
    required this.child,
    required this.orderId,
    required this.currentSenderId,
    required this.currentSenderName,
    required this.isDriver,
    required this.recipientLabel,
  });

  @override
  State<ChatNotificationListenerWrapper> createState() => _ChatNotificationListenerWrapperState();
}

class _ChatNotificationListenerWrapperState extends State<ChatNotificationListenerWrapper> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatSub;
  String? _bannerText;
  String? _bannerSender;
  bool _showBanner = false;
  Timer? _hideTimer;
  int _lastMessageTimestamp = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _listenForIncomingMessages();
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _listenForIncomingMessages() {
    _chatSub = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .collection('messages')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          final senderId = data['senderId'] as String? ?? '';
          final text = data['text'] as String? ?? '';
          final int ts = data['createdAt'] != null && data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).millisecondsSinceEpoch
              : DateTime.now().millisecondsSinceEpoch;

          if (senderId != widget.currentSenderId && ts > _lastMessageTimestamp) {
            _lastMessageTimestamp = ts;
            _triggerHeadsUp(text);
          }
        }
      }
    });
  }

  void _triggerHeadsUp(String text) {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);

    setState(() {
      _bannerSender = widget.recipientLabel;
      _bannerText = text;
      _showBanner = true;
    });

    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showBanner = false);
    });
  }

  void _openChatModal() {
    setState(() => _showBanner = false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderChatSheet(
        orderId: widget.orderId,
        senderId: widget.currentSenderId,
        senderName: widget.currentSenderName,
        isDriver: widget.isDriver,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          top: _showBanner ? MediaQuery.of(context).padding.top + 8 : -100,
          left: 16,
          right: 16,
          child: GestureDetector(
            onTap: _openChatModal,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF14171D),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5A93C), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE5A93C),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chat_bubble, color: Colors.black, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _bannerSender?.toUpperCase() ?? 'NEW MESSAGE',
                            style: const TextStyle(
                              color: Color(0xFFE5A93C),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _bannerText ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
