import 'package:flutter/material.dart';
import 'package:rotary_dial/rotary_dial.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rotary Dial Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const RotaryDialScreen(),
    );
  }
}

class RotaryDialScreen extends StatefulWidget {
  const RotaryDialScreen({super.key});

  @override
  State<RotaryDialScreen> createState() => _RotaryDialScreenState();
}

class _RotaryDialScreenState extends State<RotaryDialScreen> {
  String _code = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(title: const Text('Rotary Dial Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                _code.isEmpty ? 'Dial a number' : _code,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 48),
            // Example 1: Dark Mode Dial
            RotaryDial(
              onDigitSelected: (digit) {
                setState(() {
                  if (_code.length >= 10) _code = '';
                  _code += digit;
                });
              },
              theme: const RotaryDialTheme(
                baseFillColor: Colors.black87,
                ringFillColor: Colors.white,
                numberColor: Colors.white,
                centerFillColor: Colors.black,
                centerOutlineColor: Colors.white,
                holeOutlineColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _code = ''),
        child: const Icon(Icons.clear),
      ),
    );
  }
}
