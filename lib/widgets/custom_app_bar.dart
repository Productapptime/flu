// lib/widgets/custom_app_bar.dart
import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isSearching;
  final TextEditingController searchController;
  final bool darkMode;
  final Widget? leadingIcon;
  final List<Widget> actions;
  final ValueChanged<String>? onSearchChanged;

  const CustomAppBar({
    super.key,
    required this.title,
    required this.isSearching,
    required this.searchController,
    required this.darkMode,
    this.leadingIcon,
    required this.actions,
    this.onSearchChanged,
  });

  Widget _buildSearchField() {
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: 'Dosyalarda ara...', 
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: darkMode ? Colors.red.withOpacity(0.7) : Colors.white70
        )
      ),
      style: TextStyle(color: darkMode ? Colors.red : Colors.white),
      autofocus: true,
      onChanged: onSearchChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: isSearching ? _buildSearchField() : Text(title),
      centerTitle: true,
      leading: leadingIcon,
      backgroundColor: darkMode ? Colors.black : Colors.red,
      foregroundColor: darkMode ? Colors.red : Colors.white,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(48);
}
