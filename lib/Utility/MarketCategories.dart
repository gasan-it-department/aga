import 'package:flutter/material.dart';

class MarketCategories {
  static const List<Map<String, dynamic>> categories = [
    {'label': 'Meals', 'icon': Icons.restaurant_rounded},
    {'label': 'Milk Tea', 'icon': Icons.local_cafe_rounded},
    {'label': 'Coffee', 'icon': Icons.coffee_rounded},
    {'label': 'Drinks', 'icon': Icons.local_drink_rounded},
    {'label': 'Bread', 'icon': Icons.bakery_dining_rounded},
    {'label': 'Pastries', 'icon': Icons.cake_rounded},
    {'label': 'Cakes', 'icon': Icons.cake_outlined},
    {'label': 'Snacks', 'icon': Icons.cookie_rounded},
    {'label': 'Desserts', 'icon': Icons.icecream_rounded},
    {'label': 'Other', 'icon': Icons.more_horiz_rounded},
  ];

  static List<String> get labels => categories.map((e) => e['label'] as String).toList();
}
