import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Utility/ChatService.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';

class ChatThread extends StatefulWidget {
  final String? conversationId;
  final String? sellerId;
  final String? itemId;
  final String title;
  final int? buyerScore;

  const ChatThread({
    super.key,
    this.conversationId,
    this.sellerId,
    this.itemId,
    required this.title,
    this.buyerScore,
  }) : assert(conversationId != null || sellerId != null);

  @override
  State<ChatThread> createState() => _ChatThreadState();
}

class _ChatThreadState extends State<ChatThread> {
  final ChatService _chat = ChatService();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  static const Color primaryDark = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color themeOrange = Color(0xFFEE4D2D);

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _channel;
  String? _uid;
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _uid = _chat.currentUserId;
    _conversationId = widget.conversationId;
    final conversationId = _conversationId;
    if (conversationId == null || conversationId.isEmpty) {
      _loading = false;
      return;
    }
    ChatService.activeConversationId = conversationId;
    _load(conversationId);
  }

  Future<void> _load(String conversationId) async {
    final msgs = await _chat.fetchMessages(conversationId);
    if (!mounted) return;
    setState(() {
      _messages = msgs;
      _loading = false;
    });
    _chat.markRead(conversationId);
    _scrollToBottom();
    _subscribe(conversationId);
  }

  void _subscribe(String conversationId) {
    if (_channel != null) return;

    _channel = _chat.subscribeMessages(conversationId, (row) {
      if (_messages.any((m) => m['message_id'] == row['message_id'])) return;
      setState(() => _messages.add(row));
      if (row['message_sender_id'] != _uid) _chat.markRead(conversationId);
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _input.clear();
    try {
      var conversationId = _conversationId;
      if (conversationId == null || conversationId.isEmpty) {
        final sellerId = widget.sellerId;
        if (sellerId == null || sellerId.isEmpty) {
          throw Exception('Missing seller conversation target.');
        }

        final conversation = await _chat.getOrCreateConversation(
          sellerId: sellerId,
          itemId: widget.itemId,
        );
        conversationId = conversation?['conversation_id']?.toString();
        if (conversationId == null || conversationId.isEmpty) {
          throw Exception('Unable to start conversation.');
        }

        _conversationId = conversationId;
        ChatService.activeConversationId = conversationId;
        _subscribe(conversationId);
      }

      await _chat.sendMessage(conversationId: conversationId, body: text);
    } catch (_) {
      _input.text = text;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    if (_conversationId != null &&
        ChatService.activeConversationId == _conversationId) {
      ChatService.activeConversationId = null;
    }
    if (_channel != null) Supabase.instance.client.removeChannel(_channel!);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            if (widget.buyerScore != null) ...[
              const SizedBox(width: 8),
              _scoreBadge(widget.buyerScore!),
            ],
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildBubble(_messages[i]),
                  ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _scoreBadge(int score) {
    final color = score >= 80
        ? const Color(0xFF16A34A)
        : score >= 50
        ? const Color(0xFFF59E0B)
        : const Color(0xFFDC2626);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showScoreDetails(score),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          "Score $score",
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  void _showScoreDetails(int score) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_user_outlined),
            SizedBox(width: 10),
            Text('Buyer Score'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$score / 150',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: primaryDark,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'This score helps sellers identify reliable buyers and reduce fake or abusive orders.',
                style: TextStyle(color: textSecondary, height: 1.45),
              ),
              const SizedBox(height: 20),
              _scoreInfoRow(
                Icons.flag_outlined,
                'Starts at 100',
                'New buyers begin with a normal reliability score.',
              ),
              _scoreInfoRow(
                Icons.remove_circle_outline,
                'Order cancellation penalties',
                'Cancelling a placed order reduces 5 points. Cancelling after preparation begins reduces 20 points.',
              ),
              _scoreInfoRow(
                Icons.lock_outline_rounded,
                'Feature restrictions',
                'Scores below 80 indicate caution. Scores below 50 may be prohibited from purchasing or using certain marketplace features.',
              ),
              _scoreInfoRow(
                Icons.trending_up_rounded,
                'Score range',
                'Scores are kept between 0 and 150 and can improve through reliable marketplace activity.',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _scoreInfoRow(IconData icon, String title, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: themeOrange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(color: textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 56,
            color: textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 10),
          Text(
            "Send a message to start the conversation.",
            style: TextStyle(
              color: textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMessage(Map<String, dynamic> m) {
    final dialog = ClassicDialog();
    dialog.setTitle("Delete message");
    dialog.setMessage("This message will be permanently deleted.");
    dialog.setNegativeMessage("Cancel");
    dialog.setPositiveMessage("Delete");
    dialog.showTwoButtonDialog(context, (_) => dialog.dismissDialog(), (
      _,
    ) async {
      dialog.dismissDialog();
      final id = m['message_id'].toString();
      try {
        await _chat.deleteMessage(id);
        if (mounted) {
          setState(
            () =>
                _messages.removeWhere((x) => x['message_id'].toString() == id),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to delete message")),
          );
        }
      }
    });
  }

  Widget _buildBubble(Map<String, dynamic> m) {
    final bool mine = m['message_sender_id'] == _uid;
    final String body = (m['message_body'] ?? '').toString();
    final num secs =
        num.tryParse(m['message_date_added']?.toString() ?? '0') ?? 0;
    final String time = Utility().formatEpochToTime((secs * 1000).toInt());
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: mine ? () => _confirmDeleteMessage(m) : null,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.74,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: mine ? themeOrange : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 3),
              bottomRight: Radius.circular(mine ? 3 : 14),
            ),
            border: mine ? null : Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                body,
                style: TextStyle(
                  color: mine ? Colors.white : primaryDark,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                time,
                style: TextStyle(
                  color: mine ? Colors.white70 : textSecondary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: cardBorder)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                  filled: true,
                  fillColor: bgColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: themeOrange, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: themeOrange,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sending ? null : _send,
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
