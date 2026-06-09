import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Utility/ChatService.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';

class ChatThread extends StatefulWidget {
  final String conversationId;
  final String title;

  const ChatThread({super.key, required this.conversationId, required this.title});

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

  @override
  void initState() {
    super.initState();
    _uid = _chat.currentUserId;
    ChatService.activeConversationId = widget.conversationId;
    _load();
  }

  Future<void> _load() async {
    final msgs = await _chat.fetchMessages(widget.conversationId);
    if (!mounted) return;
    setState(() {
      _messages = msgs;
      _loading = false;
    });
    _chat.markRead(widget.conversationId);
    _scrollToBottom();
    _channel = _chat.subscribeMessages(widget.conversationId, (row) {
      if (_messages.any((m) => m['message_id'] == row['message_id'])) return;
      setState(() => _messages.add(row));
      if (row['message_sender_id'] != _uid) _chat.markRead(widget.conversationId);
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _input.clear();
    try {
      await _chat.sendMessage(conversationId: widget.conversationId, body: text);
    } catch (_) {
      _input.text = text;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    if (ChatService.activeConversationId == widget.conversationId) {
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
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: cardBorder, height: 1)),
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 56, color: textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text("Say hello 👋", style: TextStyle(color: textSecondary, fontWeight: FontWeight.w700, fontSize: 14)),
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
    dialog.showTwoButtonDialog(
      context,
      (_) => dialog.dismissDialog(),
      (_) async {
        dialog.dismissDialog();
        final id = m['message_id'].toString();
        try {
          await _chat.deleteMessage(id);
          if (mounted) setState(() => _messages.removeWhere((x) => x['message_id'].toString() == id));
        } catch (_) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete message")));
        }
      },
    );
  }

  Widget _buildBubble(Map<String, dynamic> m) {
    final bool mine = m['message_sender_id'] == _uid;
    final String body = (m['message_body'] ?? '').toString();
    final num secs = num.tryParse(m['message_date_added']?.toString() ?? '0') ?? 0;
    final String time = Utility().formatEpochToTime((secs * 1000).toInt());
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: mine ? () => _confirmDeleteMessage(m) : null,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
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
              Text(body, style: TextStyle(color: mine ? Colors.white : primaryDark, fontSize: 14, height: 1.35)),
              const SizedBox(height: 3),
              Text(time, style: TextStyle(color: mine ? Colors.white70 : textSecondary, fontSize: 9.5, fontWeight: FontWeight.w600)),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: themeOrange, width: 1.5)),
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
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
