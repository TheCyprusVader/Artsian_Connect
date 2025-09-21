



// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      if (_isLogin) {
        final cred = await auth.signInWithEmailAndPassword(email: _email.text.trim(), password: _password.text);
        final doc = await firestore.collection('users').doc(cred.user!.uid).get();
        if (!doc.exists) {
          await firestore.collection('users').doc(cred.user!.uid).set({'email': _email.text.trim(), 'createdAt': FieldValue.serverTimestamp()});
        }
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email.text.trim(), password: _password.text);
        await firestore.collection('users').doc(cred.user!.uid).set({'email': _email.text.trim(), 'createdAt': FieldValue.serverTimestamp()});
      }
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
    } on FirebaseAuthException catch (e) {
      var msg = 'Authentication failed';
      if (e.message != null) msg = e.message!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Theme.of(context).colorScheme.error));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.handshake, size: 84, color: Colors.deepPurple),
                const SizedBox(height: 12),
                Text('Welcome to Artisan Connect', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text('Connect with artisans — buy and sell handcrafted goods.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email))),
                      const SizedBox(height: 12),
                      TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock))),
                      const SizedBox(height: 16),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: _submit,
                              child: Text(_isLogin ? 'Login' : 'Create account'),
                            ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() => _isLogin = !_isLogin),
                        child: Text(_isLogin ? 'Create an account' : 'I already have an account'),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                Text('By continuing you agree to our Terms', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
