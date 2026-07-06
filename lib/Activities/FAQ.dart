import 'package:flutter/material.dart';

class FAQ extends StatefulWidget {
  const FAQ({super.key});

  @override
  State<FAQ> createState() => _FAQState();
}

class _FAQState extends State<FAQ> {
  final Color bgColor = const Color(0xFFF1F5F9);
  final Color primaryDark = const Color(0xFF0F172A);
  final Color themeOrange = const Color(0xFFEE4D2D);
  final Color primaryBlue = const Color(0xFF2563EB);
  final Color cardBorder = const Color(0xFFE2E8F0);
  final Color textSecondary = const Color(0xFF64748B);

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  int? _openIndex;

  static const List<_FaqCategory> _categories = [
    _FaqCategory(
      title: "Getting Started",
      icon: Icons.rocket_launch_rounded,
      items: [
        _FaqItem(
          "What is AGA?",
          "AGA (Aga Gasan App) is an all-in-one community app for Marinduque. It combines a local online marketplace, maritime port and vessel tracking, tourism information, and emergency/disaster (MDRRMO) services in a single platform.",
        ),
        _FaqItem(
          "Do I need an account?",
          "You can browse the marketplace, shops, and public information freely. An account is required to add items to your cart, place orders, sell products, or access personalized features.",
        ),
        _FaqItem(
          "How do I sign up?",
          "Tap the profile or sign-in option and register with your details. Once verified, you can shop as a buyer or apply to become a seller from your account settings.",
        ),
      ],
    ),
    _FaqCategory(
      title: "Shopping & Orders",
      icon: Icons.shopping_bag_rounded,
      items: [
        _FaqItem(
          "How do I find items near me?",
          "The Items Gallery automatically shows products available in your municipality. Use the category strip, the 'Discover Shops' row, or the search bar (search by item name, category, or shop name) to narrow things down.",
        ),
        _FaqItem(
          "What are item variations?",
          "Some products come in variants such as size, flavor, or color, each with its own price and stock. When an item has variations, choose one before adding it to your cart or buying.",
        ),
        _FaqItem(
          "How do I add items to my cart?",
          "Open an item, select a variation if required, then tap Add to Cart. You can review everything in My Cart before checking out.",
        ),
        _FaqItem(
          "How does checkout work?",
          "From the cart, proceed to Checkout, confirm your items and quantities, choose a payment method (GCash, Maya, Cash on Delivery, or Over the Counter), and place your order.",
        ),
        _FaqItem(
          "Where can I see my orders?",
          "Go to My Orders to track the status of each purchase, view the variant and price you ordered, and check delivery progress.",
        ),
        _FaqItem(
          "What is my buying score?",
          "Your buying score starts at 100 and reflects your order history. Completed orders add 2 points. Cancelling before a seller accepts deducts 5 points, while cancelling after acceptance deducts 20 points. Scores are limited from 0 to 150.",
        ),
        _FaqItem(
          "Why is Cash on Delivery unavailable?",
          "Cash on Delivery is disabled when your buying score falls below 80. Complete orders successfully and avoid unnecessary cancellations to improve your score.",
        ),
        _FaqItem(
          "Why am I unable to place an order?",
          "Buyers with a buying score below 50 cannot place new orders. Contact an administrator for assistance or account review.",
        ),
        _FaqItem(
          "What does 'Stock: N/A' mean?",
          "It means the seller marked the item as having no fixed stock limit (for example, made-to-order or service items). These items never show as sold out.",
        ),
      ],
    ),
    _FaqCategory(
      title: "Selling",
      icon: Icons.storefront_rounded,
      items: [
        _FaqItem(
          "How do I become a seller?",
          "Set up your store profile, including your municipality address. A valid municipality is required so your products appear to nearby buyers.",
        ),
        _FaqItem(
          "How do I add a product?",
          "In My Products, tap Add New. Fill in the name, photos (up to 2), price, stock, category, and optionally add variations. New items appear at the top of your list.",
        ),
        _FaqItem(
          "Can I sell items without tracking stock?",
          "Yes. When adding an item, turn on 'Stocks not applicable'. The stock field is disabled and the item will never display as sold out.",
        ),
        _FaqItem(
          "Do I need a price if I use variations?",
          "You need either a base price or at least one variation. If you add variations, each one carries its own price and stock.",
        ),
        _FaqItem(
          "How do I hide an item?",
          "Toggle the availability switch on the product card or in the editor. Hidden items stay in your catalog but are not shown to buyers.",
        ),
      ],
    ),
    _FaqCategory(
      title: "Maritime & Ports",
      icon: Icons.directions_boat_rounded,
      items: [
        _FaqItem(
          "What maritime information is available?",
          "AGA shows port status, vessel types and statuses, and related maritime activity for Marinduque's ports to help you plan travel and shipping.",
        ),
        _FaqItem(
          "Can I buy travel tickets?",
          "Travel ticket features let you view and manage trips where supported. Availability depends on the route and operator.",
        ),
      ],
    ),
    _FaqCategory(
      title: "Safety & Emergency",
      icon: Icons.health_and_safety_rounded,
      items: [
        _FaqItem(
          "What are the MDRRMO features?",
          "The MDRRMO section provides disaster and emergency information, marine and weather notifications, incident reports, and emergency response resources for the community.",
        ),
        _FaqItem(
          "How do I get emergency alerts?",
          "Enable notifications so you receive marine and MDRRMO advisories, announcements, and community alerts as they are published.",
        ),
        _FaqItem(
          "What is the Emergency QR?",
          "You can download an Emergency QR that holds key information for quick access by responders during an emergency.",
        ),
      ],
    ),
    _FaqCategory(
      title: "Account & Support",
      icon: Icons.support_agent_rounded,
      items: [
        _FaqItem(
          "How do I update my delivery address?",
          "Open your delivery address settings to add or edit addresses. Your municipality affects which marketplace items you can see.",
        ),
        _FaqItem(
          "Is my data secure?",
          "Your information is stored securely and used only to operate the app's features, such as orders, deliveries, and notifications.",
        ),
        _FaqItem(
          "How do I get more help?",
          "Follow AGA on Facebook for updates and announcements, or reach out through the contact options in the app for additional support.",
        ),
      ],
    ),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_FaqEntry> get _entries {
    final list = <_FaqEntry>[];
    for (final c in _categories) {
      for (final i in c.items) {
        list.add(_FaqEntry(c, i));
      }
    }
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where((e) =>
            e.item.question.toLowerCase().contains(q) ||
            e.item.answer.toLowerCase().contains(q) ||
            e.category.title.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text("Help & FAQ",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.3)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              _buildHeader(),
              _buildSearch(),
              Expanded(
                child: entries.isEmpty
                    ? _buildEmpty()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        physics: const BouncingScrollPhysics(),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _buildTile(entries[index], index),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("How can we help?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: primaryDark, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text("Find answers about shopping, selling, maritime services, and safety on AGA.",
              style: TextStyle(fontSize: 13.5, color: textSecondary, height: 1.4, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() {
          _query = v;
          _openIndex = null;
        }),
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryDark),
        decoration: InputDecoration(
          hintText: "Search questions...",
          hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
          prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded, color: textSecondary, size: 18),
                  onPressed: () => setState(() {
                    _searchCtrl.clear();
                    _query = '';
                  }),
                ),
          filled: true,
          fillColor: bgColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeOrange, width: 1.5)),
        ),
      ),
    );
  }

  Widget _buildTile(_FaqEntry entry, int index) {
    final bool open = _openIndex == index;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: open ? themeOrange.withValues(alpha: 0.4) : cardBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey(index),
          initiallyExpanded: open,
          onExpansionChanged: (v) => setState(() => _openIndex = v ? index : null),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: themeOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(entry.category.icon, color: themeOrange, size: 18),
          ),
          title: Text(entry.item.question,
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: primaryDark, height: 1.3)),
          trailing: Icon(open ? Icons.remove_rounded : Icons.add_rounded, color: textSecondary, size: 20),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(entry.item.answer,
                  style: TextStyle(fontSize: 13.5, color: textSecondary, height: 1.55, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text("No matching questions",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: primaryDark)),
            const SizedBox(height: 6),
            Text("Try a different keyword.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _FaqCategory {
  final String title;
  final IconData icon;
  final List<_FaqItem> items;
  const _FaqCategory({required this.title, required this.icon, required this.items});
}

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem(this.question, this.answer);
}

class _FaqEntry {
  final _FaqCategory category;
  final _FaqItem item;
  _FaqEntry(this.category, this.item);
}
