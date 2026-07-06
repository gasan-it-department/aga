import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/ChatService.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Activities/Chat/ChatThread.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';

class ChatInbox extends StatefulWidget {
  final String? sellerId;
  const ChatInbox({super.key, this.sellerId});

  @override
  State<ChatInbox> createState() => _ChatInboxState();
}

class _ChatInboxState extends State<ChatInbox> {
  final ChatService _chat = ChatService();

  static const Color primaryDark = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color themeOrange = Color(0xFFEE4D2D);

  List<Map<String, dynamic>> _conversations = [];
  Map<String, String> _names = {};
  Map<String, int> _buyerScores = {};
  bool _loading = true;

  bool get _sellerMode => widget.sellerId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fetched = await _chat.fetchConversations(sellerId: widget.sellerId);
    final convos = _chat.deduplicateConversations(
      fetched,
      sellerMode: _sellerMode,
    );
    final sellerIds = <String>{};
    final buyerIds = <String>{};
    for (final c in convos) {
      if (_sellerMode) {
        buyerIds.add(c['conversation_buyer_id'].toString());
      } else {
        sellerIds.add(c['conversation_seller_id'].toString());
      }
    }
    final sellerNames = await _chat.fetchSellerNames(sellerIds);
    final buyerNames = await _chat.fetchUserNames(buyerIds);
    final buyerScores = await _chat.fetchUserBuyingScores(buyerIds);
    if (!mounted) return;
    setState(() {
      _conversations = convos;
      _names = {...sellerNames, ...buyerNames};
      _buyerScores = buyerScores;
      _loading = false;
    });
  }

  String _titleFor(Map<String, dynamic> c) {
    final String otherId =
        (_sellerMode ? c['conversation_buyer_id'] : c['conversation_seller_id'])
            .toString();
    return _names[otherId] ?? (_sellerMode ? 'Buyer' : 'Store');
  }

  int _unreadFor(Map<String, dynamic> c) {
    final raw = _sellerMode
        ? c['conversation_seller_unread']
        : c['conversation_buyer_unread'];
    return int.tryParse(raw?.toString() ?? '0') ?? 0;
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
        title: const Text(
          "Messages",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _conversations.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, indent: 76, color: cardBorder),
                itemBuilder: (_, i) => _buildTile(_conversations[i]),
              ),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 64,
            color: textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            "No messages yet",
            style: TextStyle(
              color: primaryDark,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Your conversations will appear here.",
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(Map<String, dynamic> c) {
    final title = _titleFor(c);
    final buyerId = c['conversation_buyer_id']?.toString();
    final score = _sellerMode && buyerId != null ? _buyerScores[buyerId] : null;
    final preview = (c['conversation_last_message'] ?? 'Tap to chat')
        .toString();
    final unread = _unreadFor(c);
    final num secs =
        num.tryParse(c['conversation_last_message_at']?.toString() ?? '0') ?? 0;
    final String ago = secs > 0
        ? Utility().getEpochTimeAgo((secs * 1000).toInt())
        : '';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: themeOrange.withValues(alpha: 0.12),
        child: Text(
          title.isNotEmpty ? title[0].toUpperCase() : '?',
          style: const TextStyle(
            color: themeOrange,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: primaryDark,
                fontSize: 14.5,
              ),
            ),
          ),
          if (score != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _showScoreDetails(score),
              child: _scoreBadge(score),
            ),
          ],
        ],
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: unread > 0 ? primaryDark : textSecondary,
          fontSize: 13,
          fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            ago,
            style: TextStyle(
              color: textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: themeOrange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatThread(
              conversationId: c['conversation_id'].toString(),
              title: title,
              buyerScore: score,
            ),
          ),
        );
        _load();
      },
      onLongPress: () => _confirmDeleteConversation(c, title),
    );
  }

  Widget _scoreBadge(int score) {
    final color = score >= 80
        ? const Color(0xFF16A34A)
        : score >= 50
        ? const Color(0xFFF59E0B)
        : const Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        "$score",
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  void _showScoreDetails(int score) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buyer Score'),
        content: Text(
          'Score: $score / 150\n\n'
          'Buyer Score helps sellers identify reliable buyers and reduce fake orders.\n\n'
          'Buyers start at 100. Cancelling a placed order reduces 5 points, while cancelling after preparation begins reduces 20 points.\n\n'
          'Scores below 80 indicate caution. Scores below 50 may restrict purchases and other marketplace features.',
          style: const TextStyle(height: 1.45),
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

  void _confirmDeleteConversation(Map<String, dynamic> c, String title) {
    final dialog = ClassicDialog();
    dialog.setTitle("Delete conversation");
    dialog.setMessage(
      "Delete conversation with $title? All messages will be permanently removed.",
    );
    dialog.setNegativeMessage("Cancel");
    dialog.setPositiveMessage("Delete");
    dialog.showTwoButtonDialog(context, (_) => dialog.dismissDialog(), (
      _,
    ) async {
      dialog.dismissDialog();
      final id = c['conversation_id'].toString();
      try {
        await _chat.deleteConversation(id);
        if (mounted)
          setState(
            () => _conversations.removeWhere(
              (x) => x['conversation_id'].toString() == id,
            ),
          );
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to delete conversation")),
          );
      }
    });
  }
}
