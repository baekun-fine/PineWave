import 'dart:math';

import 'package:flutter/material.dart';

import '../models/track_model.dart';

const double trackLaneHeight = 258;
const double trackHeaderWidth = 208;

class TrackHeaderLane extends StatelessWidget {
  const TrackHeaderLane({
    super.key,
    required this.track,
    required this.positionMs,
    required this.isPlaying,
    required this.hasSolo,
    required this.moveMode,
    required this.isRecordingTarget,
    required this.recordingElapsedMs,
    required this.recordingLevel,
    required this.onLoadFile,
    required this.onVolumeChanged,
    required this.onPanChanged,
    required this.onReverbChanged,
    required this.onReverbDetails,
    required this.onMuteChanged,
    required this.onSoloChanged,
    required this.onRecordArmedChanged,
    required this.onMixSelectedChanged,
    required this.onClearAudio,
    required this.onDeleteTrack,
    required this.onMoveByMs,
  });

  final TrackModel track;
  final int positionMs;
  final bool isPlaying;
  final bool hasSolo;
  final bool moveMode;
  final bool isRecordingTarget;
  final int recordingElapsedMs;
  final double recordingLevel;
  final VoidCallback onLoadFile;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onPanChanged;
  final ValueChanged<double> onReverbChanged;
  final VoidCallback onReverbDetails;
  final ValueChanged<bool> onMuteChanged;
  final ValueChanged<bool> onSoloChanged;
  final ValueChanged<bool> onRecordArmedChanged;
  final ValueChanged<bool> onMixSelectedChanged;
  final VoidCallback onClearAudio;
  final VoidCallback onDeleteTrack;
  final ValueChanged<int> onMoveByMs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color accent = _trackAccent(track.id);
    final bool audible = !track.muted && (!hasSolo || track.solo);
    final double peakLevel = isRecordingTarget && audible
        ? (recordingLevel * track.volume).clamp(0, 1).toDouble()
        : _peakLevelForTrack(track, positionMs, isPlaying, audible);

    return SizedBox(
      height: trackLaneHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF15181D),
          border: Border(
            right: const BorderSide(color: Color(0xFF2A2E36)),
            bottom: const BorderSide(color: Color(0xFF242831)),
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ColoredBox(color: accent),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 5, 6, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        _iconForTrack(track.id),
                        color: Colors.white70,
                        size: 17,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        track.hasAudio
                            ? 'AUDIO'
                            : isRecordingTarget
                            ? 'REC'
                            : 'EMPTY',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white54,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      _MiniIconButton(
                        tooltip: 'Load file into this track',
                        onPressed: onLoadFile,
                        icon: Icons.folder_open_rounded,
                      ),
                      _MiniIconButton(
                        tooltip: 'Clear audio',
                        onPressed: track.hasAudio ? onClearAudio : null,
                        icon: Icons.close_rounded,
                      ),
                      _MiniIconButton(
                        tooltip: 'Delete track',
                        onPressed: onDeleteTrack,
                        icon: Icons.delete_outline_rounded,
                        color: const Color(0xFFFF7043),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: <Widget>[
                      _MiniToggle(
                        label: 'R',
                        active: track.recordArmed,
                        activeColor: const Color(0xFFFF1744),
                        onTap: () => onRecordArmedChanged(!track.recordArmed),
                      ),
                      const SizedBox(width: 4),
                      _MiniToggle(
                        label: 'M',
                        active: track.muted,
                        activeColor: const Color(0xFFFF7043),
                        onTap: () => onMuteChanged(!track.muted),
                      ),
                      const SizedBox(width: 4),
                      _MiniToggle(
                        label: 'S',
                        active: track.solo,
                        activeColor: accent,
                        onTap: () => onSoloChanged(!track.solo),
                      ),
                      const SizedBox(width: 4),
                      _MiniToggle(
                        label: 'Mix',
                        active: track.mixSelected,
                        activeColor: const Color(0xFF00E0A4),
                        onTap: track.hasAudio
                            ? () => onMixSelectedChanged(!track.mixSelected)
                            : () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  _PeakMeter(level: peakLevel),
                  if (moveMode && track.hasAudio) ...<Widget>[
                    const SizedBox(height: 3),
                    _MoveNudgeControls(onMoveByMs: onMoveByMs, accent: accent),
                  ],
                  const SizedBox(height: 5),
                  _LabeledMiniSlider(
                    label: 'Vol',
                    valueLabel: '${(track.volume * 100).round()}',
                    value: track.volume,
                    min: 0,
                    max: 1,
                    color: accent,
                    step: 0.01,
                    onChanged: onVolumeChanged,
                  ),
                  _LabeledMiniSlider(
                    label: 'Pan',
                    valueLabel: _formatPan(track.pan),
                    value: track.pan,
                    min: -1,
                    max: 1,
                    color: accent,
                    step: 0.01,
                    onChanged: onPanChanged,
                  ),
                  _LabeledMiniSlider(
                    label: 'Rev',
                    valueLabel: '${(track.reverb * 100).round()}',
                    value: track.reverb,
                    min: 0,
                    max: 1,
                    color: accent,
                    step: 0.01,
                    onChanged: onReverbChanged,
                    trailing: IconButton(
                      tooltip: 'Reverb details',
                      onPressed: onReverbDetails,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 20,
                        height: 20,
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.tune_rounded, size: 14),
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

class TrackWaveformLane extends StatelessWidget {
  const TrackWaveformLane({
    super.key,
    required this.track,
    required this.sessionDurationMs,
    required this.width,
    required this.positionMs,
    required this.pixelsPerSecond,
    required this.isPlaying,
    required this.hasSolo,
    required this.moveMode,
    required this.isRecordingTarget,
    required this.recordingStartPositionMs,
    required this.recordingElapsedMs,
    required this.recordingPeaks,
    required this.onSeek,
    required this.onMoveByMs,
  });

  final TrackModel track;
  final int sessionDurationMs;
  final double width;
  final int positionMs;
  final double pixelsPerSecond;
  final bool isPlaying;
  final bool hasSolo;
  final bool moveMode;
  final bool isRecordingTarget;
  final int recordingStartPositionMs;
  final int recordingElapsedMs;
  final List<double> recordingPeaks;
  final ValueChanged<double> onSeek;
  final ValueChanged<int> onMoveByMs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color accent = _trackAccent(track.id);
    final bool audible = !track.muted && (!hasSolo || track.solo);

    return SizedBox(
      width: width,
      height: trackLaneHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: moveMode
            ? null
            : (TapDownDetails details) => _seek(details.localPosition.dx),
        onHorizontalDragUpdate: (DragUpdateDetails details) {
          if (moveMode) {
            final int deltaMs =
                ((details.delta.dx / max(pixelsPerSecond, 1)) * 1000).round();
            onMoveByMs(deltaMs);
            return;
          }
          _seek(details.localPosition.dx);
        },
        child: Stack(
          children: <Widget>[
            CustomPaint(
              painter: _TrackWaveformPainter(
                track: track,
                sessionDurationMs: max(sessionDurationMs, 1),
                accent: accent,
                positionMs: positionMs,
                pixelsPerSecond: pixelsPerSecond,
                muted: !audible,
                moveMode: moveMode,
                isRecordingTarget: isRecordingTarget,
                recordingStartPositionMs: recordingStartPositionMs,
                recordingElapsedMs: recordingElapsedMs,
                recordingPeaks: recordingPeaks,
              ),
              size: Size.infinite,
            ),
            for (final clip in track.clips)
              _ClipTitle(
                left: (clip.startMs / 1000) * pixelsPerSecond + 8,
                title: clip.name,
                theme: theme,
              ),
            if (isRecordingTarget)
              _ClipTitle(
                left: (recordingStartPositionMs / 1000) * pixelsPerSecond + 8,
                title: 'Recording...',
                theme: theme,
              ),
            if (moveMode)
              Positioned(
                right: 8,
                bottom: 6,
                child: Icon(
                  Icons.open_with_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _seek(double dx) {
    onSeek((dx / max(1, width)).clamp(0, 1));
  }
}

class _MiniToggle extends StatelessWidget {
  const _MiniToggle({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double width = label.length > 1 ? 35 : 30;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        width: width,
        height: 21,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? activeColor : const Color(0xFF242932),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0xFF343A44)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: active ? Colors.black : Colors.white70,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.color,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Icon(
            icon,
            size: 15,
            color: enabled
                ? color ?? Colors.white70
                : Colors.white.withValues(alpha: 0.22),
          ),
        ),
      ),
    );
  }
}

class _MoveNudgeControls extends StatelessWidget {
  const _MoveNudgeControls({required this.onMoveByMs, required this.accent});

  final ValueChanged<int> onMoveByMs;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _NudgeButton(label: '-10', onTap: () => onMoveByMs(-10)),
            _NudgeButton(label: '-1', onTap: () => onMoveByMs(-1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.open_with_rounded,
                size: 13,
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
            _NudgeButton(label: '+1', onTap: () => onMoveByMs(1)),
            _NudgeButton(label: '+10', onTap: () => onMoveByMs(10)),
          ],
        ),
      ),
    );
  }
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _ClipTitle extends StatelessWidget {
  const _ClipTitle({
    required this.left,
    required this.title,
    required this.theme,
  });

  final double left;
  final String title;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: 6,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeakMeter extends StatelessWidget {
  const _PeakMeter({required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    final Color color = level > 0.86
        ? const Color(0xFFFF1744)
        : level > 0.62
        ? const Color(0xFFFFA000)
        : const Color(0xFF00E676);

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 8,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFF252B34)),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 70),
                  width: constraints.maxWidth * level.clamp(0, 1),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        const Color(0xFF00E676),
                        level > 0.62 ? const Color(0xFFFFA000) : color,
                        level > 0.86 ? const Color(0xFFFF1744) : color,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LabeledMiniSlider extends StatelessWidget {
  const _LabeledMiniSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.step,
    required this.onChanged,
    this.trailing,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final Color color;
  final double step;
  final ValueChanged<double> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 48,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 20,
            child: Row(
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white60,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: 3),
                  trailing!,
                ],
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: SizedBox(
                    width: 34,
                    child: Text(
                      valueLabel,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 28,
            child: Row(
              children: <Widget>[
                _SliderStepButton(
                  icon: Icons.remove_rounded,
                  onTap: () =>
                      onChanged((value - step).clamp(min, max).toDouble()),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbColor: color,
                      activeTrackColor: color,
                      inactiveTrackColor: const Color(0xFF303642),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 13,
                      ),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                    ),
                    child: Slider(
                      value: value,
                      min: min,
                      max: max,
                      onChanged: onChanged,
                    ),
                  ),
                ),
                _SliderStepButton(
                  icon: Icons.add_rounded,
                  onTap: () =>
                      onChanged((value + step).clamp(min, max).toDouble()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderStepButton extends StatelessWidget {
  const _SliderStepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 18,
        height: 18,
        child: Icon(icon, size: 14, color: Colors.white70),
      ),
    );
  }
}

class _TrackWaveformPainter extends CustomPainter {
  const _TrackWaveformPainter({
    required this.track,
    required this.sessionDurationMs,
    required this.accent,
    required this.positionMs,
    required this.pixelsPerSecond,
    required this.muted,
    required this.moveMode,
    required this.isRecordingTarget,
    required this.recordingStartPositionMs,
    required this.recordingElapsedMs,
    required this.recordingPeaks,
  });

  final TrackModel track;
  final int sessionDurationMs;
  final Color accent;
  final int positionMs;
  final double pixelsPerSecond;
  final bool muted;
  final bool moveMode;
  final bool isRecordingTarget;
  final int recordingStartPositionMs;
  final int recordingElapsedMs;
  final List<double> recordingPeaks;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;

    canvas.drawRect(bounds, Paint()..color = const Color(0xFF0B0E13));
    _drawGrid(canvas, size);

    if (!track.hasAudio && !isRecordingTarget) {
      final Rect emptyRect = Rect.fromLTWH(0, 0, size.width, size.height);
      _drawEmptyClip(canvas, emptyRect, size);
      return;
    }

    for (final clip in track.clips) {
      _drawAudioClip(canvas, clip, size);
    }

    if (isRecordingTarget) {
      final Rect liveRect = Rect.fromLTWH(
        (recordingStartPositionMs / 1000) * pixelsPerSecond,
        0,
        max(2, (recordingElapsedMs / 1000) * pixelsPerSecond),
        size.height,
      );
      _drawRecordingClip(canvas, liveRect, size);
    }
  }

  void _drawAudioClip(Canvas canvas, TrackClipModel clip, Size size) {
    final double startX = (clip.startMs / 1000) * pixelsPerSecond;
    final double clipWidth = max(1, (clip.durationMs / 1000) * pixelsPerSecond);
    final Rect clipRect = Rect.fromLTWH(startX, 0, clipWidth, size.height);
    final Rect visibleClip = clipRect.intersect(Offset.zero & size);
    if (visibleClip.isEmpty) {
      return;
    }

    canvas.drawRect(
      visibleClip,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            accent.withValues(alpha: muted ? 0.18 : 0.95),
            accent.withValues(alpha: muted ? 0.10 : 0.62),
          ],
        ).createShader(visibleClip),
    );

    final int localPositionMs = positionMs - clip.startMs;
    if (localPositionMs > 0) {
      final double playedWidth = min(
        clipWidth,
        (localPositionMs / max(clip.durationMs, 1)) * clipWidth,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          startX,
          0,
          playedWidth,
          size.height,
        ).intersect(Offset.zero & size),
        Paint()..color = Colors.white.withValues(alpha: 0.10),
      );
    }

    _drawClipPeaks(canvas, clip, clipRect, size);

    canvas.drawLine(
      Offset(visibleClip.left, size.height / 2),
      Offset(visibleClip.right, size.height / 2),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.34)
        ..strokeWidth = 1,
    );

    if (moveMode) {
      canvas.drawRect(
        visibleClip.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white.withValues(alpha: 0.62)
          ..strokeWidth = 1,
      );
    }
  }

  void _drawClipPeaks(
    Canvas canvas,
    TrackClipModel clip,
    Rect clipRect,
    Size size,
  ) {
    if (clip.waveformPeaks.isEmpty || clip.sourceDurationMs <= 0) {
      return;
    }
    final Paint peakPaint = Paint()
      ..color = muted ? Colors.white30 : Colors.black.withValues(alpha: 0.52)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    final int startPeak =
        ((clip.sourceOffsetMs / clip.sourceDurationMs) *
                clip.waveformPeaks.length)
            .floor()
            .clamp(0, clip.waveformPeaks.length - 1);
    final int endPeak =
        (((clip.sourceOffsetMs + clip.durationMs) / clip.sourceDurationMs) *
                clip.waveformPeaks.length)
            .ceil()
            .clamp(startPeak + 1, clip.waveformPeaks.length);
    final int sampleCount = max(1, endPeak - startPeak);
    for (int index = 0; index < sampleCount; index += 1) {
      final int peakIndex = (startPeak + index).clamp(
        0,
        clip.waveformPeaks.length - 1,
      );
      final double x =
          clipRect.left + ((index / max(sampleCount - 1, 1)) * clipRect.width);
      if (x < 0 || x > size.width) {
        continue;
      }
      final double normalizedPeak = clip.waveformPeaks[peakIndex]
          .clamp(0, 1)
          .toDouble();
      final double halfHeight = normalizedPeak * (size.height * 0.34);
      canvas.drawLine(
        Offset(x, size.height / 2 - halfHeight),
        Offset(x, size.height / 2 + halfHeight),
        peakPaint,
      );
    }
  }

  void _drawEmptyClip(Canvas canvas, Rect clipRect, Size size) {
    final Rect visibleClip = clipRect.intersect(Offset.zero & size);
    canvas.drawRect(visibleClip, Paint()..color = const Color(0xFF131820));
    canvas.drawRect(
      visibleClip.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF3A414D)
        ..strokeWidth = 1,
    );
  }

  void _drawRecordingClip(Canvas canvas, Rect clipRect, Size size) {
    final Rect visibleClip = clipRect.intersect(Offset.zero & size);
    if (visibleClip.isEmpty) {
      return;
    }

    canvas.drawRect(
      visibleClip,
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[Color(0xFFFF1744), Color(0xFF8B1028)],
        ).createShader(visibleClip),
    );
    canvas.drawRect(
      visibleClip,
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );

    final Paint livePeakPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.78)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    if (recordingPeaks.isEmpty) {
      canvas.drawLine(
        Offset(visibleClip.left, size.height / 2),
        Offset(visibleClip.right, size.height / 2),
        livePeakPaint,
      );
    } else {
      final int sampleCount = recordingPeaks.length;
      for (int index = 0; index < sampleCount; index += 1) {
        final double x =
            clipRect.left +
            ((index / max(sampleCount - 1, 1)) * max(clipRect.width, 1));
        if (x < visibleClip.left || x > visibleClip.right) {
          continue;
        }
        final double peak = recordingPeaks[index].clamp(0, 1).toDouble();
        final double halfHeight = peak * size.height * 0.38;
        canvas.drawLine(
          Offset(x, size.height / 2 - halfHeight),
          Offset(x, size.height / 2 + halfHeight),
          livePeakPaint,
        );
      }
    }

    canvas.drawRect(
      visibleClip.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withValues(alpha: 0.46)
        ..strokeWidth = 1,
    );
  }

  void _drawGrid(Canvas canvas, Size size) {
    final double gridStepSeconds = _gridStepSeconds(pixelsPerSecond);
    final Paint gridPaint = Paint()
      ..color = const Color(0xFF38414D)
      ..strokeWidth = 0.9;
    for (double x = 0; x < size.width; x += pixelsPerSecond * gridStepSeconds) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()
        ..color = const Color(0xFF242831)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _TrackWaveformPainter oldDelegate) {
    return oldDelegate.track != track ||
        oldDelegate.sessionDurationMs != sessionDurationMs ||
        oldDelegate.accent != accent ||
        oldDelegate.positionMs != positionMs ||
        oldDelegate.pixelsPerSecond != pixelsPerSecond ||
        oldDelegate.muted != muted ||
        oldDelegate.moveMode != moveMode ||
        oldDelegate.isRecordingTarget != isRecordingTarget ||
        oldDelegate.recordingStartPositionMs != recordingStartPositionMs ||
        oldDelegate.recordingElapsedMs != recordingElapsedMs ||
        oldDelegate.recordingPeaks != recordingPeaks;
  }
}

double _peakLevelForTrack(
  TrackModel track,
  int positionMs,
  bool isPlaying,
  bool audible,
) {
  if (!isPlaying ||
      !audible ||
      !track.hasAudio ||
      track.clips.every((TrackClipModel clip) => clip.waveformPeaks.isEmpty)) {
    return 0;
  }
  final activeClip = track.clips.cast<TrackClipModel?>().firstWhere(
    (TrackClipModel? clip) =>
        clip != null && positionMs >= clip.startMs && positionMs <= clip.endMs,
    orElse: () => null,
  );
  if (activeClip == null || activeClip.waveformPeaks.isEmpty) {
    return 0;
  }
  final int sourcePositionMs =
      activeClip.sourceOffsetMs + (positionMs - activeClip.startMs);
  final double fraction =
      sourcePositionMs / max(activeClip.sourceDurationMs, 1);
  final int index = (fraction * (activeClip.waveformPeaks.length - 1))
      .round()
      .clamp(0, activeClip.waveformPeaks.length - 1);
  return (activeClip.waveformPeaks[index] * track.volume)
      .clamp(0, 1)
      .toDouble();
}

double _gridStepSeconds(double pixelsPerSecond) {
  if (pixelsPerSecond >= 1200) {
    return 0.01;
  }
  if (pixelsPerSecond >= 600) {
    return 0.05;
  }
  if (pixelsPerSecond >= 260) {
    return 0.1;
  }
  if (pixelsPerSecond >= 120) {
    return 0.5;
  }
  if (pixelsPerSecond >= 64) {
    return 2;
  }
  if (pixelsPerSecond >= 32) {
    return 5;
  }
  if (pixelsPerSecond >= 16) {
    return 10;
  }
  if (pixelsPerSecond >= 8) {
    return 15;
  }
  if (pixelsPerSecond >= 4) {
    return 30;
  }
  return 60;
}

Color _trackAccent(String id) {
  final int hash = id.codeUnits.fold<int>(
    0,
    (int value, int unit) => (value * 31 + unit) & 0xFFFFFFFF,
  );
  final List<Color> colors = <Color>[
    const Color(0xFF00E0A4),
    const Color(0xFFFF4D6D),
    const Color(0xFF14B8FF),
    const Color(0xFFFFD166),
    const Color(0xFFFF3DF2),
    const Color(0xFF7BFF3D),
  ];
  return colors[hash % colors.length];
}

IconData _iconForTrack(String id) {
  final List<IconData> icons = <IconData>[
    Icons.piano_rounded,
    Icons.graphic_eq_rounded,
    Icons.music_note_rounded,
    Icons.mic_rounded,
    Icons.album_rounded,
  ];
  final int hash = id.codeUnits.fold<int>(
    0,
    (int value, int unit) => value + unit,
  );
  return icons[hash % icons.length];
}

String _formatPan(double pan) {
  if (pan.abs() < 0.02) {
    return 'C';
  }
  final int amount = (pan.abs() * 100).round();
  return pan < 0 ? 'L$amount' : 'R$amount';
}
