import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/track_model.dart';

class WaveformCache {
  const WaveformCache();

  Future<CachedWaveform?> read(String sourceKey) async {
    try {
      final file = await _cacheFile(sourceKey);
      if (!await file.exists()) {
        return null;
      }
      final payload =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return CachedWaveform(
        durationMs: (payload['durationMs'] as num? ?? 0).round(),
        peaks: (payload['peaks'] as List<dynamic>? ?? const [])
            .map((dynamic value) => (value as num).toDouble())
            .toList(growable: false),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write({
    required String sourceKey,
    required int durationMs,
    required List<double> peaks,
  }) async {
    final file = await _cacheFile(sourceKey);
    await file.writeAsString(
      jsonEncode(<String, Object?>{'durationMs': durationMs, 'peaks': peaks}),
      flush: true,
    );
  }

  Future<File> _cacheFile(String sourceKey) async {
    final root = await getTemporaryDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}waveform_cache',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final fileName = '${_hashKey(sourceKey)}.json';
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  String _hashKey(String value) {
    const int offset = 0x811C9DC5;
    const int prime = 0x01000193;
    var hash = offset;
    for (final int byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * prime) & 0xFFFFFFFF;
    }
    return hash.toUnsigned(32).toRadixString(16).padLeft(8, '0');
  }
}
