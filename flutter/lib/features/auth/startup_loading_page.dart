import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/brand_logo.dart';

class StartupLoadingPage extends StatefulWidget {
  const StartupLoadingPage({super.key});

  @override
  State<StartupLoadingPage> createState() => _StartupLoadingPageState();
}

class _StartupLoadingPageState extends State<StartupLoadingPage> {
  static const _steps = [
    'Cargando docentes',
    'Cargando usuarios',
    'Cargando tutorías',
    'Preparando notificaciones',
  ];
  int _step = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 450), (timer) {
      if (!mounted) return;
      if (_step == _steps.length - 1) {
        timer.cancel();
        context.go('/session');
      } else {
        setState(() => _step++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_step + 1) / _steps.length;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 1.06,
                  child: const BrandLogo(
                    width: 104,
                    height: 82,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Preparando SearchTeach',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 24),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    _steps[_step],
                    key: ValueKey(_step),
                    style: const TextStyle(color: Color(0xFF687083)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
