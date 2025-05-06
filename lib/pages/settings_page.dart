import 'package:flutter/material.dart';
import 'package:serverapp/services/api_service.dart';

class SettingsPage extends StatelessWidget {
  final ApiService apiService;

  const SettingsPage({super.key, required this.apiService});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: apiService.getLogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Błąd połączenia'));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(8.0),
          child: Text(snapshot.data ?? 'Brak logów', style: const TextStyle(fontSize: 16)),
        );
      },
    );
  }
}