import 'package:demeter/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:floating_bubbles/floating_bubbles.dart';
import 'package:demeter/login_page.dart';
import 'package:demeter/register_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:page_transition/page_transition.dart';
import 'package:flutter_driver/driver_extension.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase only after potential driver setup
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (const bool.fromEnvironment('ENABLE_DRIVER_EXTENSION')) {
    enableFlutterDriverExtension();  // Enable conditionally
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Demeter',
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/dashboard': (context) => DashboardPage( // Modify this line
          userId: ModalRoute.of(context)!.settings.arguments as String,
        ),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: Container(color: Colors.green[300])),
        Positioned.fill(
          child: FloatingBubbles.alwaysRepeating(
            noOfBubbles: 25,
            colorsOfBubbles: const [Colors.purpleAccent, Colors.purple],
            sizeFactor: 0.2,
            opacity: 200,
            speed: BubbleSpeed.slow,
            paintingStyle: PaintingStyle.fill,
            shape: BubbleShape.circle,
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Image.asset(
                'assets/images/logo.png',
                height: 250,
                width: 250,
              ),
              const SizedBox(height: 144),

              // Buttons with Styling
              SizedBox(
                width: 200,
                child: Column(
                  children: [
                    ElevatedButton(
                      key: const ValueKey('loginButton'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent[100],
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          PageTransition(
                            type: PageTransitionType.fade,
                            duration: const Duration(milliseconds: 400),
                            child: const LoginPage(),
                          ),
                        );
                      },
                      child: const Text('Login'),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: Divider(color: Colors.grey[600], thickness: 2)),
                        const SizedBox(width: 10),
                        Text('OR', style: TextStyle(color: Colors.grey[600], fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(child: Divider(color: Colors.grey[600], thickness: 2)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      key: const ValueKey('registerButton'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent[100],
                      ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.fade,
                              duration: const Duration(milliseconds: 400),
                              child: const RegisterPage(),
                            ),
                          );
                        },
                      child: const Text('Register'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
