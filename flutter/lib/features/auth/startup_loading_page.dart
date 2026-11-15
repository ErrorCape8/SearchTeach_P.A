import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/neu/neu.dart';
import '../../core/widgets/brand_logo.dart';
import '../pa/pa_widgets.dart';

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

  double _progress = 0.0;
  final List<String> _messages = [
    'Cargando tutorías…',
    'Preparando todo…',
    'Casi listo…',
  ];
  int _msgIndex = 0;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() {
        _progress = (_progress + 0.07).clamp(0.0, 1.0);
        if (_progress > 0.33 && _msgIndex == 0) _msgIndex = 1;
        if (_progress > 0.66 && _msgIndex == 1) _msgIndex = 2;
      });
      if (_progress >= 1.0) {
        _progressTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.error;
    return Scaffold(
      backgroundColor: Neu.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: NeuSurface(
              radius: 26,
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 36,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLogo(
                      width: 140, height: 86, accentColor: _brandBlue),
                  const SizedBox(height: 18),
                  Text(
                    'Preparando SearchTeach',
                    textAlign: TextAlign.center,
                    style: neuPoppins(
                      size: 21,
                      weight: FontWeight.w700,
                      color: Neu.heading,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (error == null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 12,
                          backgroundColor: Neu.muted.withOpacity(0.2),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(_brandBlue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        _messages[_msgIndex],
                        key: ValueKey<int>(_msgIndex),
                        textAlign: TextAlign.center,
                        style: neuBody(
                          size: 13.5,
                          color: Neu.muted,
                        ),
                      ),
                    ),
                  ] else ...[
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: Neu.error,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: neuBody(size: 13, color: Neu.muted),
                    ),
                    const SizedBox(height: 20),
                    NeuButton(
                      'Reintentar carga',
                      icon: Icons.refresh_rounded,
                      small: true,
                      expand: false,
                      onPressed: widget.onRetry,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: widget.onBack,
                      child: Text(
                        'Volver al inicio de sesión',
                        style: neuBody(size: 13, color: _brandBlue),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NeuLinearProgressBar extends StatefulWidget {
  const NeuLinearProgressBar({
    this.initialTarget = 0.75,
    this.initialDuration = const Duration(milliseconds: 850),
    this.color = const Color(0xFF1E3FA8),
    this.height = 10.0,
    super.key,
  });

  final double initialTarget;
  final Duration initialDuration;
  final Color color;
  final double height;

  @override
  State<NeuLinearProgressBar> createState() => _NeuLinearProgressBarState();
}

class _NeuLinearProgressBarState extends State<NeuLinearProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fastAnimation;
  Timer? _slowTimer;
  double _currentProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.initialDuration,
    );
    _fastAnimation =
        Tween<double>(begin: 0.0, end: widget.initialTarget).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(() {
            if (mounted) setState(() => _currentProgress = _fastAnimation.value);
          });

    _controller.forward().then((_) {
      _slowTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
        if (!mounted) return;
        if (_currentProgress < 0.95) {
          setState(() {
            _currentProgress += 0.02;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _currentProgress.clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NeuSunken(
          radius: widget.height,
          padding: const EdgeInsets.all(2.5),
          child: SizedBox(
            height: widget.height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: constraints.maxWidth * progress,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.height),
                        gradient: LinearGradient(
                          colors: [
                            widget.color.withValues(alpha: 0.75),
                            widget.color,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${(progress * 100).toInt()}%',
            style: neuPoppins(
              size: 11,
              weight: FontWeight.w600,
              color: Neu.muted,
            ),
          ),
        ),
      ],
    );
  }
}
