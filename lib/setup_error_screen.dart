import 'package:flutter/material.dart';

class SetupErrorScreen extends StatelessWidget {
  const SetupErrorScreen({super.key, required this.errorMessage});

  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F5),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E2D24), width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'App setup required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E2D24),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'This APK was built without required environment values. Rebuild with --dart-define-from-file.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4A3F35),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4EFEA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        errorMessage,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: Color(0xFF4A3F35),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Example:\nflutter build apk --release --dart-define-from-file=dart_defines.local.json',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4A3F35),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
