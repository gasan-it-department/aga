import 'package:flutter/material.dart';

class MarketCategories {
  static const List<Map<String, dynamic>> categories = [
    {'label': 'Meals', 'icon': Icons.restaurant_rounded},
    {'label': 'Local Delicacies', 'icon': Icons.rice_bowl_rounded},
    {'label': 'Homemade Food', 'icon': Icons.soup_kitchen_rounded},
    {'label': 'Milk Tea', 'icon': Icons.local_cafe_rounded},
    {'label': 'Coffee', 'icon': Icons.coffee_rounded},
    {'label': 'Drinks', 'icon': Icons.local_drink_rounded},
    {'label': 'Bread', 'icon': Icons.bakery_dining_rounded},
    {'label': 'Pastries', 'icon': Icons.cake_rounded},
    {'label': 'Cakes', 'icon': Icons.cake_outlined},
    {'label': 'Snacks', 'icon': Icons.cookie_rounded},
    {'label': 'Desserts', 'icon': Icons.icecream_rounded},
    {'label': 'Preserves & Condiments', 'icon': Icons.kitchen_rounded},
    {'label': 'Fresh Seafood', 'icon': Icons.set_meal_rounded},
    {'label': 'Dried Seafood', 'icon': Icons.set_meal_outlined},
    {'label': 'Processed Seafood', 'icon': Icons.lunch_dining_rounded},
    {'label': 'Souvenirs', 'icon': Icons.card_giftcard_rounded},
    {'label': 'Handicrafts', 'icon': Icons.handyman_rounded},
    {'label': 'Clothing', 'icon': Icons.checkroom_rounded},
    {'label': 'Footwear', 'icon': Icons.hiking_rounded},
    {'label': 'Fashion Accessories', 'icon': Icons.watch_rounded},
    {'label': 'Electronics', 'icon': Icons.devices_rounded},
    {'label': 'Mobile Accessories', 'icon': Icons.phone_android_rounded},
    {'label': 'Computer Accessories', 'icon': Icons.computer_rounded},
    {'label': 'Flowers', 'icon': Icons.local_florist_rounded},
    {'label': 'Gifts', 'icon': Icons.redeem_rounded},
    {'label': 'Grocery', 'icon': Icons.local_grocery_store_rounded},
    {'label': 'Household Essentials', 'icon': Icons.home_rounded},
    {'label': 'Personal Care', 'icon': Icons.spa_rounded},
    {'label': 'General Merchandise', 'icon': Icons.inventory_2_rounded},
    {'label': 'Other', 'icon': Icons.more_horiz_rounded},
  ];

  static List<String> get labels =>
      categories.map((e) => e['label'] as String).toList();
}
