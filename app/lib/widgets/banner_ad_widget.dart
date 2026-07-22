import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Real AdMob banner unit on Android (see AndroidManifest.xml for the
/// matching real App ID). No iOS AdMob app has been created yet, so iOS
/// stays on Google's public test unit — TODO: swap once one exists,
/// alongside the test App ID still in Info.plist.
String get _bannerAdUnitId {
  if (Platform.isAndroid) return 'ca-app-pub-3851784424831046/2371381571';
  if (Platform.isIOS) return 'ca-app-pub-3940256099942544/2934735716';
  throw UnsupportedError('Ads are only wired up for Android/iOS');
}

/// The app's sole ad slot (Section 9, CLAUDE.md): one thin banner pinned
/// to the bottom of the screen — no interstitials, no audio ads, ever.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  late final BannerAd _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isLoaded = true),
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();
    return SizedBox(
      width: _bannerAd.size.width.toDouble(),
      height: _bannerAd.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd),
    );
  }
}
