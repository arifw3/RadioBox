import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

const _userAgent = 'DialWave-HeroProbe/1.0 (+https://github.com/arifw3/RadioBox)';
const _timeout = Duration(seconds: 8);

/// Reads just enough of a live Icecast/Shoutcast stream to grab one
/// "StreamTitle" ICY metadata block, then stops — used to show a live
/// artist/song preview for a station the user isn't actually playing
/// (the home screen hero). Never touches audio playback; this is a
/// separate, short-lived HTTP connection that closes itself the moment it
/// has (or fails to get) the metadata.
class IcyMetadataProbe {
  IcyMetadataProbe(this._client);

  final http.Client _client;

  Future<String?> fetchStreamTitle(String streamUrl) async {
    final uri = Uri.tryParse(streamUrl);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return null;
    }

    http.StreamedResponse? response;
    var consumedStream = false;
    try {
      final request = http.Request('GET', uri)
        ..headers['User-Agent'] = _userAgent
        // Asks the server to interleave metadata blocks into the body at
        // `icy-metaint`-byte intervals — the whole ICY protocol this
        // depends on.
        ..headers['Icy-MetaData'] = '1';

      response = await _client.send(request).timeout(_timeout);

      final metaInt = int.tryParse(response.headers['icy-metaint'] ?? '');
      if (metaInt == null || metaInt <= 0) {
        // Station doesn't support inline ICY metadata at all — nothing to
        // read here regardless of how long we wait.
        return null;
      }

      consumedStream = true;
      var audioBytesRemaining = metaInt;
      int? metaLength;
      final metaBuffer = <int>[];

      await for (final chunk in response.stream.timeout(_timeout)) {
        var i = 0;
        while (i < chunk.length) {
          if (audioBytesRemaining > 0) {
            final skip = audioBytesRemaining < (chunk.length - i)
                ? audioBytesRemaining
                : (chunk.length - i);
            audioBytesRemaining -= skip;
            i += skip;
            continue;
          }
          if (metaLength == null) {
            // Metadata block length is this byte * 16 (Shoutcast/Icecast
            // protocol); 0 means "no change since last block".
            metaLength = chunk[i] * 16;
            i++;
            if (metaLength == 0) {
              audioBytesRemaining = metaInt;
              metaLength = null;
            }
            continue;
          }
          final need = metaLength - metaBuffer.length;
          final take = need < (chunk.length - i) ? need : (chunk.length - i);
          metaBuffer.addAll(chunk.sublist(i, i + take));
          i += take;
          if (metaBuffer.length >= metaLength) {
            // Returning here ends the `await for` early, which cancels the
            // underlying stream subscription for us — no manual close.
            final text = latin1.decode(metaBuffer, allowInvalid: true);
            final match = RegExp("StreamTitle='([^']*)'").firstMatch(text);
            return match?.group(1)?.trim();
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      if (!consumedStream) {
        unawaited(response?.stream.listen((_) {}).cancel());
      }
    }
  }
}
