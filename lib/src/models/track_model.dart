import 'dart:math';

class ReverbSettings {
  const ReverbSettings({
    required this.presetId,
    required this.mix,
    required this.roomSize,
    required this.decay,
    required this.damp,
    required this.preDelayMs,
    required this.width,
  });

  final String presetId;
  final double mix;
  final double roomSize;
  final double decay;
  final double damp;
  final double preDelayMs;
  final double width;

  static const ReverbSettings defaultValue = ReverbSettings(
    presetId: 'vocal_plate',
    mix: 0.48,
    roomSize: 0.58,
    decay: 0.62,
    damp: 0.42,
    preDelayMs: 32,
    width: 0.78,
  );

  static const List<ReverbPreset> presets = <ReverbPreset>[
    ReverbPreset(
      id: 'vocal_plate',
      name: 'Vocal Plate',
      description: 'Bright and clear vocal plate',
      settings: defaultValue,
    ),
    ReverbPreset(
      id: 'small_room',
      name: 'Small Room',
      description: 'Short and natural room',
      settings: ReverbSettings(
        presetId: 'small_room',
        mix: 0.32,
        roomSize: 0.28,
        decay: 0.34,
        damp: 0.52,
        preDelayMs: 12,
        width: 0.48,
      ),
    ),
    ReverbPreset(
      id: 'warm_hall',
      name: 'Warm Hall',
      description: 'Warm long hall reverb',
      settings: ReverbSettings(
        presetId: 'warm_hall',
        mix: 0.56,
        roomSize: 0.82,
        decay: 0.78,
        damp: 0.64,
        preDelayMs: 38,
        width: 0.86,
      ),
    ),
    ReverbPreset(
      id: 'wide_pop',
      name: 'Wide Pop',
      description: 'Wide modern pop vocal',
      settings: ReverbSettings(
        presetId: 'wide_pop',
        mix: 0.50,
        roomSize: 0.66,
        decay: 0.58,
        damp: 0.32,
        preDelayMs: 52,
        width: 1,
      ),
    ),
    ReverbPreset(
      id: 'dream_tail',
      name: 'Dream Tail',
      description: 'Dreamy long reverb tail',
      settings: ReverbSettings(
        presetId: 'dream_tail',
        mix: 0.68,
        roomSize: 0.92,
        decay: 0.94,
        damp: 0.46,
        preDelayMs: 68,
        width: 0.94,
      ),
    ),
    ReverbPreset(
      id: 'dry_intimate',
      name: 'Dry Intimate',
      description: 'Close vocal with subtle space',
      settings: ReverbSettings(
        presetId: 'dry_intimate',
        mix: 0.18,
        roomSize: 0.20,
        decay: 0.22,
        damp: 0.58,
        preDelayMs: 8,
        width: 0.35,
      ),
    ),
  ];

  ReverbSettings copyWith({
    String? presetId,
    double? mix,
    double? roomSize,
    double? decay,
    double? damp,
    double? preDelayMs,
    double? width,
  }) {
    return ReverbSettings(
      presetId: presetId ?? this.presetId,
      mix: mix ?? this.mix,
      roomSize: roomSize ?? this.roomSize,
      decay: decay ?? this.decay,
      damp: damp ?? this.damp,
      preDelayMs: preDelayMs ?? this.preDelayMs,
      width: width ?? this.width,
    );
  }

  Map<String, Object?> toPlatformMap() {
    return <String, Object?>{
      'mix': mix,
      'roomSize': roomSize,
      'decay': decay,
      'damp': damp,
      'preDelayMs': preDelayMs,
      'width': width,
    };
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'presetId': presetId,
      'mix': mix,
      'roomSize': roomSize,
      'decay': decay,
      'damp': damp,
      'preDelayMs': preDelayMs,
      'width': width,
    };
  }

  static ReverbSettings fromJson(Map<String, dynamic> json) {
    return ReverbSettings(
      presetId: json['presetId'] as String? ?? 'custom',
      mix: (json['mix'] as num? ?? defaultValue.mix).toDouble(),
      roomSize: (json['roomSize'] as num? ?? defaultValue.roomSize).toDouble(),
      decay: (json['decay'] as num? ?? defaultValue.decay).toDouble(),
      damp: (json['damp'] as num? ?? defaultValue.damp).toDouble(),
      preDelayMs: (json['preDelayMs'] as num? ?? defaultValue.preDelayMs)
          .toDouble(),
      width: (json['width'] as num? ?? defaultValue.width).toDouble(),
    );
  }
}

class ReverbPreset {
  const ReverbPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.settings,
  });

  final String id;
  final String name;
  final String description;
  final ReverbSettings settings;
}

class TrackClipModel {
  TrackClipModel({
    required this.id,
    required this.name,
    required this.filePath,
    required this.startMs,
    required this.durationMs,
    required this.sourceOffsetMs,
    required this.sourceDurationMs,
    required List<double> waveformPeaks,
  }) : waveformPeaks = List<double>.unmodifiable(waveformPeaks);

  final String id;
  final String name;
  final String filePath;
  final int startMs;
  final int durationMs;
  final int sourceOffsetMs;
  final int sourceDurationMs;
  final List<double> waveformPeaks;

  int get endMs => startMs + durationMs;

  TrackClipModel copyWith({
    String? id,
    String? name,
    String? filePath,
    int? startMs,
    int? durationMs,
    int? sourceOffsetMs,
    int? sourceDurationMs,
    List<double>? waveformPeaks,
  }) {
    return TrackClipModel(
      id: id ?? this.id,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      startMs: startMs ?? this.startMs,
      durationMs: durationMs ?? this.durationMs,
      sourceOffsetMs: sourceOffsetMs ?? this.sourceOffsetMs,
      sourceDurationMs: sourceDurationMs ?? this.sourceDurationMs,
      waveformPeaks: waveformPeaks ?? this.waveformPeaks,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'filePath': filePath,
      'startMs': startMs,
      'durationMs': durationMs,
      'sourceOffsetMs': sourceOffsetMs,
      'sourceDurationMs': sourceDurationMs,
    };
  }
}

class TrackModel {
  TrackModel({
    required this.id,
    required this.name,
    required this.volume,
    required this.pan,
    required this.reverb,
    this.reverbSettings = ReverbSettings.defaultValue,
    required this.muted,
    required this.solo,
    required this.recordArmed,
    this.mixSelected = false,
    this.fallbackDurationMs = 30000,
    List<TrackClipModel> clips = const <TrackClipModel>[],
  }) : clips = List<TrackClipModel>.unmodifiable(clips);

  final String id;
  final String name;
  final double volume;
  final double pan;
  final double reverb;
  final ReverbSettings reverbSettings;
  final bool muted;
  final bool solo;
  final bool recordArmed;
  final bool mixSelected;
  final int fallbackDurationMs;
  final List<TrackClipModel> clips;

  bool get hasAudio => clips.isNotEmpty;
  String get filePath => hasAudio ? clips.first.filePath : '';
  List<double> get waveformPeaks =>
      hasAudio ? clips.first.waveformPeaks : const <double>[];
  int get startMs => hasAudio
      ? clips.map((TrackClipModel clip) => clip.startMs).reduce(min)
      : 0;
  int get durationMs => hasAudio ? endMs - startMs : fallbackDurationMs;
  int get endMs => hasAudio
      ? clips.map((TrackClipModel clip) => clip.endMs).reduce(max)
      : fallbackDurationMs;

  TrackModel copyWith({
    String? id,
    String? name,
    double? volume,
    double? pan,
    double? reverb,
    ReverbSettings? reverbSettings,
    bool? muted,
    bool? solo,
    bool? recordArmed,
    bool? mixSelected,
    int? fallbackDurationMs,
    List<TrackClipModel>? clips,
  }) {
    return TrackModel(
      id: id ?? this.id,
      name: name ?? this.name,
      volume: volume ?? this.volume,
      pan: pan ?? this.pan,
      reverb: reverb ?? this.reverb,
      reverbSettings: reverbSettings ?? this.reverbSettings,
      muted: muted ?? this.muted,
      solo: solo ?? this.solo,
      recordArmed: recordArmed ?? this.recordArmed,
      mixSelected: mixSelected ?? this.mixSelected,
      fallbackDurationMs: fallbackDurationMs ?? this.fallbackDurationMs,
      clips: clips ?? this.clips,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'volume': volume,
      'pan': pan,
      'reverb': reverb,
      'reverbSettings': reverbSettings.toJson(),
      'muted': muted,
      'solo': solo,
      'recordArmed': recordArmed,
      'mixSelected': mixSelected,
      'fallbackDurationMs': fallbackDurationMs,
      'clips': clips.map((TrackClipModel clip) => clip.toJson()).toList(),
    };
  }
}

class AudioRenderResult {
  const AudioRenderResult({required this.filePath});

  final String filePath;
}

class VocalSeparationResult {
  const VocalSeparationResult({
    required this.vocalsFilePath,
    required this.backingFilePath,
  });

  final String vocalsFilePath;
  final String backingFilePath;
}

class LoadedTrackPayload {
  LoadedTrackPayload({
    required this.durationMs,
    required List<double> waveformPeaks,
  }) : waveformPeaks = List<double>.unmodifiable(waveformPeaks);

  final int durationMs;
  final List<double> waveformPeaks;
}

class PlaybackPosition {
  const PlaybackPosition({
    required this.positionMs,
    required this.durationMs,
    required this.isPlaying,
    required this.recordingLevel,
  });

  final int positionMs;
  final int durationMs;
  final bool isPlaying;
  final double recordingLevel;
}

class CachedWaveform {
  CachedWaveform({required this.durationMs, required List<double> peaks})
    : peaks = List<double>.unmodifiable(peaks);

  final int durationMs;
  final List<double> peaks;
}
