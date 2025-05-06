import 'package:flutter/material.dart';
import 'package:serverapp/services/api_service.dart';
import 'package:serverapp/pages/verification_page.dart';

class RegisterPage extends StatefulWidget {
  final ApiService apiService;
  final Function? onRegisterSuccess;

  const RegisterPage({
    super.key,
    required this.apiService,
    this.onRegisterSuccess,
  });

  @override
  RegisterPageState createState() => RegisterPageState();
}

class RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _errorMessage;

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty ||
        username.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = 'All fields are required';
        });
      }
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Invalid email format';
        });
      }
      return;
    }

    if (password != confirmPassword) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Passwords do not match';
        });
      }
      return;
    }

    try {
      final success = await widget.apiService.register(
        username,
        password,
        email,
      );
      if (success) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => VerificationPage(
                  apiService: widget.apiService,
                  email: email,
                  onVerificationSuccess: () {
                    if (widget.onRegisterSuccess != null) {
                      widget.onRegisterSuccess!();
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Account verified! Please log in.'),
                          ),
                        );
                        Navigator.pop(context);
                      }
                    }
                  },
                ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '$e';
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final success = await widget.apiService.signInWithGoogle();
      if (success) {
        if (!mounted) return;
        if (widget.onRegisterSuccess != null) {
          widget.onRegisterSuccess!();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logged in with Google!')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Google Sign-In failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _register, child: const Text('Register')),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _signInWithGoogle,
              icon: const Icon(Icons.login),
              label: const Text('Sign in with Google'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.grey),
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
