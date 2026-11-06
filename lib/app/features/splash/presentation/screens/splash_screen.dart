import 'package:gowayki_lab/shared/l10n/l10n.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/brand/brand_assets.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Image.asset(
                BrandAssets.logo,
                key: const ValueKey('brand.splash.logo'),
                width: 200,
                height: 200,
                cacheWidth: 600,
                semanticLabel: context.l10n.appTitle,
              ),
            ),
            const SizedBox(height: 24),
            Text(context.l10n.preparing),
            const SizedBox(height: 20),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    ),
  );
}
