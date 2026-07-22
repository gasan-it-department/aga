import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/SupabaseExternalAuthBridge.dart';
import 'package:url_launcher/url_launcher.dart';

const _supportAccent = Color(0xFF2563EB);
const _supportBg = Color(0xFFF8FAFC);
const _supportBorder = Color(0xFFE2E8F0);
const _supportText = Color(0xFF0F172A);
const _supportMuted = Color(0xFF64748B);

class SupportTickets extends StatefulWidget {
  const SupportTickets({super.key});

  @override
  State<SupportTickets> createState() => _SupportTicketsState();
}

class _SupportTicketsState extends State<SupportTickets> {
  final _bridge = SupabaseExternalAuthBridge();
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = false;
  List<Map<String, dynamic>> _tickets = [];
  Map<String, dynamic> _contextData = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool nextPage = false}) async {
    if (nextPage && (_loadingMore || !_hasMore)) return;

    setState(() {
      if (nextPage) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
        _page = 1;
      }
    });

    try {
      if (!nextPage) {
        final contextResponse = await _bridge
            .getSupportTicketSubmissionContext();
        if (_isSuccess(contextResponse.statusCode)) {
          final decoded = _decode(contextResponse.body);
          _contextData = _asMap(_unwrapData(decoded));
        }
      }

      final targetPage = nextPage ? _page + 1 : 1;
      final ticketsResponse = await _bridge.getSupportTickets(
        page: targetPage,
        perPage: 10,
      );

      if (!_isSuccess(ticketsResponse.statusCode)) {
        throw Exception(_messageFromResponse(ticketsResponse.body));
      }

      final decoded = _decode(ticketsResponse.body);
      final tickets = _extractTickets(decoded);

      if (!mounted) return;
      setState(() {
        _page = targetPage;
        _tickets = nextPage ? [..._tickets, ...tickets] : tickets;
        _hasMore = _extractHasMore(decoded, tickets.length);
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SupportTicketForm(contextData: _contextData),
      ),
    );

    if (created == true) _load();
  }

  Future<void> _openDetails(Map<String, dynamic> ticket) async {
    final id = _ticketId(ticket);
    if (id.isEmpty) return;

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SupportTicketDetails(ticketId: id)),
    );

    if (changed == true) _load();
  }

  Future<void> _openSupportLink(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open support contact.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _supportBg,
      appBar: AppBar(
        title: const Text(
          'Report Bugs & Errors',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _supportText,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: _supportAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Report'),
      ),
      body: RefreshIndicator(onRefresh: () => _load(), child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return const _LoadingState(color: _supportAccent);
    }

    if (_error != null) {
      return _StateMessage(
        icon: Icons.error_outline_rounded,
        title: 'Unable to load reports',
        message: _error!,
        actionLabel: 'Retry',
        onAction: () => _load(),
      );
    }

    if (_tickets.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _ContactSupportCard(
            onFacebook: () => _openSupportLink(
              Uri.parse('https://www.facebook.com/agamobilefb'),
            ),
            onEmail: () =>
                _openSupportLink(Uri.parse('mailto:aga.app.support@gmail.com')),
          ),
          _StateMessage(
            icon: Icons.bug_report_outlined,
            title: 'No reports yet',
            message: 'Send bugs and errors here so support can track them.',
            actionLabel: 'Create report',
            onAction: _openCreate,
          ),
        ],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _ContactSupportCard(
            onFacebook: () => _openSupportLink(
              Uri.parse('https://www.facebook.com/agamobilefb'),
            ),
            onEmail: () =>
                _openSupportLink(Uri.parse('mailto:aga.app.support@gmail.com')),
          ),
        ),
        SliverToBoxAdapter(child: _TicketsHeader(count: _tickets.length)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          sliver: SliverList.separated(
            itemCount: _tickets.length + (_hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index >= _tickets.length) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _loadingMore
                        ? const CircularProgressIndicator()
                        : OutlinedButton(
                            onPressed: () => _load(nextPage: true),
                            child: const Text('Load more'),
                          ),
                  ),
                );
              }

              final ticket = _tickets[index];
              return _TicketCard(
                ticket: ticket,
                onTap: () => _openDetails(ticket),
              );
            },
          ),
        ),
      ],
    );
  }
}

class SupportTicketForm extends StatefulWidget {
  final Map<String, dynamic> contextData;

  const SupportTicketForm({super.key, required this.contextData});

  @override
  State<SupportTicketForm> createState() => _SupportTicketFormState();
}

class _SupportTicketFormState extends State<SupportTicketForm> {
  final _bridge = SupabaseExternalAuthBridge();
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _submitting = false;
  String? _category;
  String? _priority;

  List<String> get _categories => _extractOptions(widget.contextData, const [
    'categories',
    'ticket_categories',
    'support_categories',
  ]);

  List<String> get _priorities => _extractOptions(widget.contextData, const [
    'priorities',
    'priority_options',
  ]);

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final payload = {
        'subject': _subjectController.text.trim(),
        'description': _descriptionController.text.trim(),
        if (_category != null && _category!.isNotEmpty) 'category': _category,
        if (_priority != null && _priority!.isNotEmpty) 'priority': _priority,
      };

      final response = await _bridge.submitSupportTicket(payload);

      if (!_isSuccess(response.statusCode)) {
        throw Exception(_messageFromResponse(response.body));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report submitted.')));
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories;
    final priorities = _priorities;

    return Scaffold(
      backgroundColor: _supportBg,
      appBar: AppBar(
        title: const Text(
          'New Bug Report',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _supportText,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _Panel(
              icon: Icons.assignment_outlined,
              title: 'Report Details',
              subtitle: 'Share what happened so support can investigate it.',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _subjectController,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration('Subject'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Subject is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            if (categories.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: _inputDecoration('Category'),
                items: categories
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _category = value),
              ),
              const SizedBox(height: 14),
            ],
            if (priorities.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: _inputDecoration('Priority'),
                items: priorities
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _priority = value),
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _descriptionController,
              minLines: 6,
              maxLines: 10,
              decoration: _inputDecoration(
                'What happened?',
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Description is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _supportAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_submitting ? 'Submitting...' : 'Submit Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SupportTicketDetails extends StatefulWidget {
  final String ticketId;

  const SupportTicketDetails({super.key, required this.ticketId});

  @override
  State<SupportTicketDetails> createState() => _SupportTicketDetailsState();
}

class _SupportTicketDetailsState extends State<SupportTicketDetails> {
  final _bridge = SupabaseExternalAuthBridge();
  final _replyController = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  bool _reopening = false;
  bool _changed = false;
  String? _error;
  Map<String, dynamic> _ticket = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _bridge.getSupportTicketDetails(widget.ticketId);
      if (!_isSuccess(response.statusCode)) {
        throw Exception(_messageFromResponse(response.body));
      }

      final decoded = _decode(response.body);
      final ticket = _asMap(_unwrapData(decoded));

      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _reply() async {
    final message = _replyController.text.trim();
    if (message.isEmpty) return;

    setState(() => _sending = true);

    try {
      final response = await _bridge.replySupportTicket(widget.ticketId, {
        'message': message,
        'body': message,
      });

      if (!_isSuccess(response.statusCode)) {
        throw Exception(_messageFromResponse(response.body));
      }

      _replyController.clear();
      _changed = true;
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _reopen() async {
    setState(() => _reopening = true);

    try {
      final response = await _bridge.reopenSupportTicket(widget.ticketId);
      if (!_isSuccess(response.statusCode)) {
        throw Exception(_messageFromResponse(response.body));
      }

      _changed = true;
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _reopening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _supportBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context, _changed),
        ),
        title: const Text(
          'Report Details',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _supportText,
        elevation: 0,
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const _LoadingState(color: _supportAccent);
    }

    if (_error != null) {
      return _StateMessage(
        icon: Icons.error_outline_rounded,
        title: 'Unable to load details',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }

    final replies = _extractReplies(_ticket);
    final closed =
        _status(_ticket).toLowerCase().contains('closed') ||
        _status(_ticket).toLowerCase().contains('resolved');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TicketCard(ticket: _ticket),
        const SizedBox(height: 14),
        if (_longText(_ticket).isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _supportBorder),
            ),
            child: Text(
              _longText(_ticket),
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: _supportText,
              ),
            ),
          ),
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'Replies',
          trailing: closed
              ? OutlinedButton(
                  onPressed: _reopening ? null : _reopen,
                  child: Text(_reopening ? 'Reopening...' : 'Reopen'),
                )
              : null,
        ),
        const SizedBox(height: 10),
        if (replies.isEmpty)
          const _EmptyReplies()
        else
          ...replies.map(_ReplyTile.new),
        const SizedBox(height: 16),
        TextField(
          controller: _replyController,
          minLines: 3,
          maxLines: 6,
          decoration: _inputDecoration('Reply', alignLabelWithHint: true),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _supportAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _sending ? null : _reply,
            icon: _sending
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(_sending ? 'Sending...' : 'Send Reply'),
          ),
        ),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback? onTap;

  const _TicketCard({required this.ticket, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _supportBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _title(ticket),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _supportText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(status: _status(ticket)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle(ticket),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700, height: 1.35),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_field(ticket, const ['category', 'type']).isNotEmpty)
                    _MetaChip(_field(ticket, const ['category', 'type'])),
                  if (_field(ticket, const ['priority']).isNotEmpty)
                    _MetaChip(_field(ticket, const ['priority'])),
                  if (_date(ticket).isNotEmpty) _MetaChip(_date(ticket)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  final Map<String, dynamic> reply;

  const _ReplyTile(this.reply);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _supportBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _field(reply, const [
                  'user_name',
                  'name',
                  'author',
                  'created_by',
                ]).isEmpty
                ? 'Support'
                : _field(reply, const [
                    'user_name',
                    'name',
                    'author',
                    'created_by',
                  ]),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            _field(reply, const ['message', 'body', 'content', 'reply']),
            style: const TextStyle(height: 1.4, color: _supportText),
          ),
          if (_date(reply).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _date(reply),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = normalized.contains('open') || normalized.contains('new')
        ? Colors.green
        : normalized.contains('closed') || normalized.contains('resolved')
        ? Colors.grey
        : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.isEmpty ? 'Pending' : status,
        style: TextStyle(
          color: color.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String text;

  const _MetaChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TicketsHeader extends StatelessWidget {
  final int count;

  const _TicketsHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _supportBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _supportAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bug_report_rounded, color: _supportAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Support Tickets',
                  style: TextStyle(
                    color: _supportText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$count active ${count == 1 ? 'report' : 'reports'} in your account',
                  style: const TextStyle(color: _supportMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Panel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _supportBorder),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: _supportAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _supportAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _supportText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: _supportMuted, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _supportText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Container(
          height: 76,
          width: 76,
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: _supportAccent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 38, color: _supportAccent),
        ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _supportText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _supportMuted, height: 1.4),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _supportAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}

class _ContactSupportCard extends StatelessWidget {
  final VoidCallback onFacebook;
  final VoidCallback onEmail;

  const _ContactSupportCard({required this.onFacebook, required this.onEmail});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _supportBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Need help?',
            style: TextStyle(
              color: _supportText,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Contact the AGA support team directly.',
            style: TextStyle(color: _supportMuted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onFacebook,
                  icon: const Icon(Icons.facebook_rounded),
                  label: const Text('Facebook'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1877F2),
                    side: const BorderSide(color: Color(0xFF1877F2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEmail,
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Email'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _supportAccent,
                    side: const BorderSide(color: _supportAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  final Color color;

  const _LoadingState({required this.color});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.32),
        Center(child: CircularProgressIndicator(color: color)),
      ],
    );
  }
}

class _EmptyReplies extends StatelessWidget {
  const _EmptyReplies();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _supportBorder),
      ),
      child: const Row(
        children: [
          Icon(Icons.forum_outlined, color: _supportMuted),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No replies yet.',
              style: TextStyle(color: _supportMuted),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(
  String label, {
  bool alignLabelWithHint = false,
}) {
  return InputDecoration(
    labelText: label,
    alignLabelWithHint: alignLabelWithHint,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _supportBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _supportBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _supportAccent, width: 1.4),
    ),
  );
}

bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

dynamic _decode(String body) {
  if (body.isEmpty) return {};
  try {
    return jsonDecode(body);
  } catch (_) {
    return {};
  }
}

dynamic _unwrapData(dynamic value) {
  if (value is Map<String, dynamic>) {
    final data = value['data'];
    if (data is Map<String, dynamic>) {
      return data['support_ticket'] ??
          data['ticket'] ??
          data['item'] ??
          data['data'] ??
          data;
    }
    return value['support_ticket'] ?? value['ticket'] ?? value['item'] ?? data;
  }
  return value;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

List<Map<String, dynamic>> _extractTickets(dynamic value) {
  dynamic source = value;
  if (source is Map) {
    source =
        source['data'] ??
        source['support_tickets'] ??
        source['tickets'] ??
        source['items'] ??
        source['results'];
  }
  if (source is Map) {
    source =
        source['data'] ??
        source['support_tickets'] ??
        source['tickets'] ??
        source['items'] ??
        source['results'];
  }
  if (source is List) {
    return source.map(_asMap).where((item) => item.isNotEmpty).toList();
  }
  return [];
}

bool _extractHasMore(dynamic value, int received) {
  if (received == 0) return false;
  if (value is Map) {
    final meta = value['meta'];
    if (meta is Map) {
      final current = int.tryParse('${meta['current_page'] ?? ''}');
      final last = int.tryParse('${meta['last_page'] ?? ''}');
      if (current != null && last != null) return current < last;
    }
    final links = value['links'];
    if (links is Map && links['next'] != null) return true;
  }
  return received >= 10;
}

List<Map<String, dynamic>> _extractReplies(Map<String, dynamic> ticket) {
  final source =
      ticket['replies'] ??
      ticket['messages'] ??
      ticket['comments'] ??
      ticket['support_ticket_replies'];
  if (source is List) {
    return source.map(_asMap).where((item) => item.isNotEmpty).toList();
  }
  return [];
}

List<String> _extractOptions(Map<String, dynamic> context, List<String> keys) {
  for (final key in keys) {
    final source = context[key];
    if (source is List) {
      return source
          .map((item) {
            if (item is Map) {
              return item['name'] ??
                  item['label'] ??
                  item['value'] ??
                  item['id'];
            }
            return item;
          })
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();
    }
  }
  return [];
}

String _ticketId(Map<String, dynamic> ticket) {
  return _field(ticket, const [
    'id',
    'support_ticket',
    'support_ticket_id',
    'ticket_id',
    'uuid',
  ]);
}

String _title(Map<String, dynamic> ticket) {
  final title = _field(ticket, const ['subject', 'title', 'name']);
  return title.isEmpty ? 'Bug or error report' : title;
}

String _subtitle(Map<String, dynamic> ticket) {
  final subtitle = _field(ticket, const [
    'description',
    'message',
    'body',
    'content',
  ]);
  return subtitle.isEmpty ? 'Tap to view report details.' : subtitle;
}

String _longText(Map<String, dynamic> ticket) {
  final text = _subtitle(ticket);
  return text == 'Tap to view report details.' ? '' : text;
}

String _status(Map<String, dynamic> ticket) {
  return _field(ticket, const ['status', 'state']).replaceAll('_', ' ');
}

String _date(Map<String, dynamic> value) {
  return _field(value, const ['created_at', 'updated_at', 'date']);
}

String _field(Map<String, dynamic> value, List<String> keys) {
  for (final key in keys) {
    final raw = value[key];
    if (raw == null) continue;
    if (raw is Map) {
      final nested = raw['name'] ?? raw['label'] ?? raw['value'];
      if (nested != null && nested.toString().trim().isNotEmpty) {
        return nested.toString().trim();
      }
    } else if (raw.toString().trim().isNotEmpty) {
      return raw.toString().trim();
    }
  }
  return '';
}

String _messageFromResponse(String body) {
  final decoded = _decode(body);
  if (decoded is Map) {
    final message = decoded['message'] ?? decoded['error'];
    if (message != null && message.toString().trim().isNotEmpty) {
      return message.toString();
    }
    final errors = decoded['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
      return first.toString();
    }
  }
  return 'Request failed. Please try again.';
}
