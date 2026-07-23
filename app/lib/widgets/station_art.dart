import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Station logos come from wherever a station's own site (or, for
/// manually-sourced ones, whatever the web had) happens to host them —
/// a real chunk of those turn out to be SVG, which CachedNetworkImage
/// can't decode at all (it silently fails to the errorWidget). This picks
/// the right renderer by file extension so callers don't have to.
class StationArt extends StatelessWidget {
  const StationArt({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorWidget,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final WidgetBuilder? errorWidget;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.toLowerCase().endsWith('.svg')) {
      return SvgPicture.network(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        placeholderBuilder: errorWidget == null
            ? null
            : (context) => const SizedBox.shrink(),
        errorBuilder: errorWidget == null
            ? null
            : (context, error, stackTrace) => errorWidget!(context),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      errorWidget: errorWidget == null
          ? null
          : (context, url, error) => errorWidget!(context),
    );
  }
}
