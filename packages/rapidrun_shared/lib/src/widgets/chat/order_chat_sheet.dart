// File: packages/rapidrun_shared/lib/src/widgets/chat/order_chat_sheet.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OrderChatSheet extends StatefulWidget {
  final String orderId;
  final String senderId;
  final String senderName;
  final bool isDriver;

  const OrderChatSheet({
    super.key,
    required this.orderId,
    required this.senderId,
    required this.senderName,
    required this.isDriver,
  });

  @override
  State<OrderChatSheet> createState() => _OrderChatSheetState();
}

class _OrderChatSheetState extends State<OrderChatSheet> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _optimisticMessages = [];

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    _msgController.clear();
    HapticFeedback.lightImpact();

    final tempMsg = {
      'senderId': widget.senderId,
      'senderName': widget.senderName,
      'isDriver': widget.isDriver,
      'text': clean,
      'createdAt': Timestamp.now(),
    };

    setState(() {
      _optimisticMessages.add(tempMsg);
    });
    _scrollToBottom();

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .collection('messages')
          .add({
        'senderId': widget.senderId,
        'senderName': widget.senderName,
        'isDriver': widget.isDriver,
        'text': clean,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ Chat send error: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);

    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      decoration: const BoxDecoration(
        color: Color(0xFF16181F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.isDriver ? 'Chat with Customer' : 'Chat with Personal Shopper',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),

          // Streamed Chat Bubbles
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .doc(widget.orderId)
                  .collection('messages')
                  .snapshots(),
              builder: (context, snapshot) {
                List<Map<String, dynamic>> messages = List.from(_optimisticMessages);

                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  final remoteDocs = snapshot.data!.docs.map((doc) => doc.data()).toList();
                  remoteDocs.sort((a, b) {
                    final aTs = a['createdAt'];
                    final bTs = b['createdAt'];
                    if (aTs is Timestamp && bTs is Timestamp) {
                      return aTs.compareTo(bTs);
                    }
                    return 0;
                  });
                  messages = remoteDocs;
                }

                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, color: Colors.white24, size: 36),
                        SizedBox(height: 8),
                        Text(
                          'Direct channel active. Send a note to your courier.',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                _scrollToBottom();

                return ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['senderId'] == widget.senderId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? gold : const Color(0xFF242833),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          msg['text'] ?? '',
                          style: TextStyle(
                            color: isMe ? Colors.black : Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Quick Action Chips
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _quickChip('Gate code is #4921'),
                _quickChip('Please leave on front porch'),
                _quickChip('Ring bell once dropped off'),
                _quickChip('Thank you!'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Message Input Field
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type instruction or update...',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: const Color(0xFF1E2129),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black),
                    icon: const Icon(Icons.send_rounded, size: 20),
                    onPressed: () => _sendMessage(_msgController.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        backgroundColor: const Color(0xFF242833),
        side: BorderSide.none,
        label: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        onPressed: () => _sendMessage(label),
      ),
    );
  }
}
