import 'package:demeter/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:floating_bubbles/floating_bubbles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:page_transition/page_transition.dart';
import 'package:demeter/login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>(); // For form validation
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    // Clean up controllers when the widget is disposed
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[300], // Set the same color
      body: Stack( // Use a Stack to layer the bubbles behind the content
        children: [
      // Bubbles
      Positioned.fill(
      child: FloatingBubbles.alwaysRepeating(
        noOfBubbles: 25,
        colorsOfBubbles: const [Colors.purpleAccent, Colors.purple],
        sizeFactor: 0.2,
        opacity: 150,
        speed: BubbleSpeed.slow,
        paintingStyle: PaintingStyle.fill,
        shape: BubbleShape.circle,
      ),
    ),

        SingleChildScrollView( // Add SingleChildScrollView here
          child: Center(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo
            Padding(
            padding: const EdgeInsets.only(top: 160.0),
              child: Image.asset('assets/images/logo.png',
              height: 250,
              width: 250,
            ),
          ),
          const SizedBox(height: 20), // Space between logo and card

          // Card
          Card(
            margin: const EdgeInsets.all(20.0),
            child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sign Up',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    // Add basic email validation
                    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your Password',
                      prefixIcon: const Icon(Icons.password),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  key: const ValueKey('registerSubmit'),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      await _registerWithEmailAndPassword();
                    }
                  },
                  child: const Text('Submit'),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account?"),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          PageTransition(
                            type: PageTransitionType.fade,
                            child: const LoginPage(),
                          ),
                        );
                      },
                      child: const Text('Login'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
        ]),
        ),
        ),
        ],
      ),
    );
  }

  Future<void> _registerWithEmailAndPassword() async {
    try {
      // Use your AuthService
      await AuthService.instance.registerWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim()
      );


      // Successful registration - Redirect to login page
      if (mounted) {
        Navigator.push(
          context,
          PageTransition(
            type: PageTransitionType.fade,
            duration: const Duration(milliseconds: 400),
            child: const LoginPage(),
          ),
        );
      }

    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showAlertDialog('Email Already in Use', 'The email address is already registered with another account.');
      } else if (e.code == 'weak-password') {
        _showAlertDialog('Weak Password', 'The password must be over 6 characters in length.');
      } else {
        _showAlertDialog('Registration Error', e.message ?? 'An unknown error occurred. Please contact the Developer');
      }
    }
  }

  void _showAlertDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
