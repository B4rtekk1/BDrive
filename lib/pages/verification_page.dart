import 'package:flutter/material.dart';
import 'package:serverapp/services/api_service.dart';

class VerificationPage extends StatefulWidget {
  final ApiService apiService;
  final String email;
  final VoidCallback onVerificationSuccess;

  const VerificationPage({
    super.key,
    required this.apiService,
    required this.email,
    required this.onVerificationSuccess,
  });

  @override
  VerificationPageState createState() => VerificationPageState();
}

class VerificationPageState extends State<VerificationPage> {
  final _codeController = TextEditingController();
  String? _errorMessage;

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Please enter the verification code';
        });
      }
      return;
    }

    try {
      final success = await widget.apiService.verifyEmailCode(widget.email, code);
      if (success) {
        if (mounted) {
          widget.onVerificationSuccess();
          ApiService.logger.i("test");
          Navigator.pushNamedAndRemoveUntil(context, "/login", (route) => false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'A verification code has been sent to ${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Verification Code'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _verifyCode,
              child: const Text('Verify'),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}