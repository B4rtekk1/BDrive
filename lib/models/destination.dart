import 'package:flutter/material.dart';

class Destination {
  const Destination(this.title, this.icon, this.selectedIcon, this.color);
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final MaterialColor color;
}

const List<Destination> allDestinations = <Destination>[
  Destination('Home', Icons.home_outlined, Icons.home, Colors.teal),
  Destination('Files', Icons.folder_outlined, Icons.folder, Colors.cyan),
  Destination('Settings', Icons.settings_outlined, Icons.settings, Colors.orange),
];