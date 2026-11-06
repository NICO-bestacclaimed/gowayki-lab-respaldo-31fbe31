import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinish});

  final VoidCallback onFinish;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _slides = [
    (
      Icons.map_rounded,
      'Tu mapa, tu ritmo',
      'Explora Arequipa y orienta tus viajes desde el mapa.',
    ),
    (
      Icons.directions_bus_filled_rounded,
      'Rutas sin conexión',
      'Consulta los recorridos de las líneas en el mapa sin conexión.',
    ),
    (
      Icons.route_rounded,
      'Planifica y llega',
      'Elige un destino y compara opciones de trayecto.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onFinish,
                child: const Text('Saltar'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(s.$1, size: 56, color: AppColors.primary),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          s.$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          s.$3,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                            color: AppColors.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index ? AppColors.primary : AppColors.outline,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: FilledButton(
                onPressed: () {
                  if (isLast) {
                    widget.onFinish();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: Text(isLast ? 'Empezar' : 'Siguiente'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
