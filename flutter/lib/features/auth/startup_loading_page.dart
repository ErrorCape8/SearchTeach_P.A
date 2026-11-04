import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/widgets/brand_logo.dart';

class StartupLoadingPage extends StatefulWidget {
  const StartupLoadingPage({
    required this.onRetry,
    required this.onBack,
    this.error,
    super.key,
  });

  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  State<StartupLoadingPage> createState() => _StartupLoadingPageState();
}

class _StartupLoadingPageState extends State<StartupLoadingPage> {
  static const _brandBlue = Color(0xFF1E3FA8);
  static const _steps = [
    'Conectando con SearchTeach',
    'Verificando tus credenciales',
    'Despertando el servidor si estaba inactivo',
    'Preparando tus clases y tutor\u{00ED}as',
  ];

  int _step = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _step = (_step + 1) % _steps.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.error;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 2,
              shadowColor: const Color(0x1F172B4D),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 36,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandLogo(width: 148, height: 94),
                    const SizedBox(height: 20),
                    const Text(
                      'Preparando SearchTeach',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF172B4D),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (error == null) ...[
                      const SizedBox.square(
                        dimension: 32,
                        child: CircularProgressIndicator(
                          color: _brandBlue,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 18),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          _steps[_step],
                          key: ValueKey(_step),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF5B6270),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ] else ...[
                      const Icon(
                        Icons.cloud_off_outlined,
                        color: _brandBlue,
                        size: 36,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF5B6270)),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: widget.onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar carga'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _brandBlue,
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onBack,
                        child: const Text('Volver al inicio de sesi\u{00F3}n'),
                      ),
                    ],
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
