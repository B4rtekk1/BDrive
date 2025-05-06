import 'package:flutter/material.dart';

enum PopUpMenuOptions { delete, rename, copy, move }

class PopUpMenu extends StatelessWidget {
  final Function(PopUpMenuOptions) onSelected;

  const PopUpMenu({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<PopUpMenuOptions>(
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<PopUpMenuOptions>>[
        const PopupMenuItem<PopUpMenuOptions>(
          value: PopUpMenuOptions.delete,
          child: Row(
            children: [
              Icon(Icons.delete),
              SizedBox(width: 8),
              Text('Delete'),
            ],
          ),
        ),
        const PopupMenuItem<PopUpMenuOptions>(
          value: PopUpMenuOptions.rename,
          child: Row(
            children: [
              Icon(Icons.edit),
              SizedBox(width: 8),
              Text('Rename'),
            ],
          ),
        ),
        const PopupMenuItem<PopUpMenuOptions>(
          value: PopUpMenuOptions.copy,
          child: Row(
            children: [
              Icon(Icons.copy),
              SizedBox(width: 8),
              Text('Copy'),
            ],
          ),
        ),
        const PopupMenuItem<PopUpMenuOptions>(
          value: PopUpMenuOptions.move,
          child: Row(
            children: [
              Icon(Icons.move_to_inbox),
              SizedBox(width: 8),
              Text('Move'),
            ],
          ),
        ),
      ],
    );
  }
}