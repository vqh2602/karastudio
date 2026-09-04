import 'dart:math' as math;

/// Native position is already expressed in source-media microseconds. Only
/// elapsed wall time since that sample (and input latency) is rate-scaled.
int estimateSourceTime({
  required int anchorUs,
  required int elapsedWallUs,
  required double speed,
  required bool advancing,
}) => math.max(
  0,
  anchorUs + (advancing ? (math.max(0, elapsedWallUs) * speed).round() : 0),
);

int recordingSourceTime({
  required int sourcePositionUs,
  required double speed,
  required int inputOffsetMs,
}) => math.max(0, sourcePositionUs + (inputOffsetMs * 1000 * speed).round());
