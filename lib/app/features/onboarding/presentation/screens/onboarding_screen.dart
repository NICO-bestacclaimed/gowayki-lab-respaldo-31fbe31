import 'package:gowayki_lab/shared/l10n/l10n.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/brand/brand_assets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinish});
  final VoidCallback onFinish;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;
  List<(String, String)> get _slides => [
    (context.l10n.onboardFind, context.l10n.onboardFindBody),
    (context.l10n.onboardAlight, context.l10n.onboardAlightBody),
    (context.l10n.onboardTime, context.l10n.onboardTimeBody),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == 2) {
      widget.onFinish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Widget _slide(BuildContext context, int page) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  BrandAssets.micros[page * 5],
                  height: (constraints.maxHeight * .48)
                      .clamp(120.0, 250.0)
                      .toDouble(),
                  cacheWidth: 900,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 1; i < 5; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Image.asset(
                            BrandAssets.micros[page * 5 + i],
                            height: 62,
                            cacheWidth: 200,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  _slides[page].$1,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _slides[page].$2,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  Image.asset(
                    BrandAssets.logo,
                    width: 62,
                    height: 62,
                    cacheWidth: 186,
                    semanticLabel: context.l10n.appTitle,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onFinish,
                    child: Text(context.l10n.skip),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (value) => setState(() => _index = value),
                children: List.generate(3, (page) => _slide(context, page)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Container(
                          margin: const EdgeInsets.all(4),
                          height: 8,
                          width: i == _index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('onboarding.next'),
                      onPressed: _next,
                      child: Text(
                        _index == 2 ? context.l10n.start : context.l10n.next,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
