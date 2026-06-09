import 'package:flutter/material.dart';

class SearchBarView extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final String searchQuery;
  final String hintText;

  // Theme colors with defaults matching your design
  final Color textSecondary;
  final Color outlineColor;
  final Color focusedColor;
  final EdgeInsetsGeometry padding;

  const SearchBarView({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.searchQuery,
    this.hintText = "Search...",
    this.textSecondary = const Color(0xFF64748B),
    this.outlineColor = const Color(0xFFE2E8F0),
    this.focusedColor = const Color(0xFF8B5CF6), // Defaults to your broadcastPurple
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7), fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: textSecondary),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear_rounded, color: textSecondary, size: 20),
            onPressed: () {
              controller.clear();
              onChanged('');
              FocusScope.of(context).unfocus(); // Drops the keyboard
            },
          )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: outlineColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: outlineColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: focusedColor, width: 1.5),
          ),
        ),
      ),
    );
  }
}
