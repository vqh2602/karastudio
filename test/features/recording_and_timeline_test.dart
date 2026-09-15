import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/core/ffmpeg/ffmpeg_service.dart';
import 'package:karastudio/core/playback/playback_clock.dart';
import 'package:karastudio/core/serialization/project_serializer.dart';
import 'package:karastudio/features/editor/editor_controller.dart';
import 'package:karastudio/features/timeline/waveform_timeline.dart';
import 'package:karastudio/features/timing/recording_overlay.dart';
import 'package:karastudio/models/project_model.dart';

class FakePlaybackClock extends ChangeNotifier implements PlaybackClock {
  @override
  bool isPlaying = false;

  @override
  int positionUs = 0;

  @override
  Duration position = Duration.zero;

  @override
  Duration duration = const Duration(seconds: 30);

  @override
  double speed = 1.0;

  @override
  Future<void> setSpeed(double target) async {
    speed = target;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration target) async {
    position = target;
    positionUs = target.inMicroseconds;
    notifyListeners();
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  for (final speed in [0.5, 0.75, 1.25, 2.0]) {
    testWidgets('tap at $speed x saves original song positions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final clock = FakePlaybackClock()..speed = speed;
      final controller =
          EditorController(
              serializer: const ProjectSerializer(),
              ffmpeg: FfmpegService(),
              playback: clock,
            )
            ..project = ProjectModel.create('Rate test').copyWith(
              settings: const ProjectSettings(
                recordingMode: 'tap',
                inputTimingOffsetMs: -80,
              ),
              lyricLines: const [
                LyricLine(
                  id: 'line',
                  text: 'nhớ em',
                  actorId: 'male',
                  tokens: [
                    LyricToken(id: 'a', text: 'nhớ', index: 0),
                    LyricToken(id: 'b', text: 'em', index: 1),
                  ],
                ),
              ],
            );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            editorControllerProvider.overrideWith((ref) => controller),
            playbackClockProvider.overrideWith((ref) => clock),
          ],
          child: MaterialApp(
            home: Scaffold(body: RecordingOverlay(onClose: () {})),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'GHI (Space)'));
      await tester.pumpAndSettle();
      for (final position in [1000000, 1500000, 4000000]) {
        clock.positionUs = position;
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
      }
      final tokens = controller.project!.lyricLines.single.tokens;
      final offset = (80000 * speed).round();
      expect(tokens[0].startUs, 1000000 - offset);
      expect(tokens[0].endUs, 1500000 - offset);
      expect(tokens[1].startUs, 1500000 - offset);
      expect(tokens[1].endUs, 4000000 - offset);
    });
  }
  group('Timeline hit-testing and subtitle track tests', () {
    late ProjectModel project;
    late FakePlaybackClock clock;

    setUp(() {
      clock = FakePlaybackClock();
      project = ProjectModel.create('Test').copyWith(
        audio: const MediaAsset(
          id: 'audio-1',
          type: MediaType.audio,
          path: '/music/song.mp3',
          durationUs: 30000000,
          sampleRate: 48000,
          channels: 2,
          codec: 'mp3',
        ),
        lyricLines: const [
          LyricLine(
            id: 'line-0',
            text: 'Em oi nay',
            actorId: 'male',
            startUs: 1000000,
            endUs: 3000000,
            tokens: [
              LyricToken(
                id: 't-0',
                index: 0,
                text: 'Em',
                startUs: 1000000,
                endUs: 1500000,
              ),
              LyricToken(
                id: 't-1',
                index: 1,
                text: 'oi',
                startUs: 1500000,
                endUs: 2000000,
              ),
              LyricToken(
                id: 't-2',
                index: 2,
                text: 'nay',
                startUs: 2000000,
                endUs: null,
              ),
            ],
          ),
          LyricLine(
            id: 'line-1',
            text: 'Co hay',
            actorId: 'female',
            startUs: 3500000,
            endUs: 5000000,
            tokens: [
              LyricToken(
                id: 't-3',
                index: 0,
                text: 'Co',
                startUs: 3500000,
                endUs: 4200000,
              ),
              LyricToken(
                id: 't-4',
                index: 1,
                text: 'hay',
                startUs: 4200000,
                endUs: 5000000,
              ),
            ],
          ),
        ],
      );
    });

    testWidgets(
      'WaveformTimeline hit-tests token with null endUs and opens quick edit',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        int? selectedLine;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1000,
                height: 250,
                child: WaveformTimeline(
                  clock: clock,
                  durationUs: 30000000,
                  waveform: null,
                  project: project,
                  onLineSelected: (lineIdx) {
                    selectedLine = lineIdx;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final gestureDetector = find.byKey(
          const Key('timeline_gesture_detector'),
        );
        final origin = tester.getTopLeft(gestureDetector);

        // 30s visible on 1000px width -> 1s = 33.33px
        // Token 'nay' starts at 2.0s = ~66.7px
        // Subtitle track center is around local y = 60.0.
        // Double-click on token 'nay' at origin + (75.0, 60.0)
        final target = origin + const Offset(75.0, 60.0);
        await tester.tapAt(target);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(target);
        await tester.pumpAndSettle();

        // Line 0 was selected
        expect(selectedLine, equals(0));

        // Quick edit dialog should appear for token 'nay'!
        expect(find.text('Chỉnh Sửa Timing: "nay"'), findsOneWidget);
      },
    );

    testWidgets(
      'RecordingOverlay Tap Mode: one tap advances exactly one word without jumping lines',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final testProject = ProjectModel.create('Test Tap Mode').copyWith(
          settings: const ProjectSettings(
            recordingMode: 'tap',
            inputTimingOffsetMs: 0,
          ),
          lyricLines: const [
            LyricLine(
              id: 'line-0',
              text: 'Mot hai ba',
              actorId: 'male',
              tokens: [
                LyricToken(id: 't-0', index: 0, text: 'Mot'),
                LyricToken(id: 't-1', index: 1, text: 'hai'),
                LyricToken(id: 't-2', index: 2, text: 'ba'),
              ],
            ),
            LyricLine(
              id: 'line-1',
              text: 'Bon nam',
              actorId: 'male',
              tokens: [
                LyricToken(id: 't-3', index: 0, text: 'Bon'),
                LyricToken(id: 't-4', index: 1, text: 'nam'),
              ],
            ),
          ],
        );

        final controller = EditorController(
          serializer: const ProjectSerializer(),
          ffmpeg: FfmpegService(),
          playback: clock,
        );
        controller.project = testProject;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              editorControllerProvider.overrideWith((ref) => controller),
              playbackClockProvider.overrideWith((ref) => clock),
            ],
            child: MaterialApp(
              home: Scaffold(body: RecordingOverlay(onClose: () {})),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Start recording
        await tester.tap(find.widgetWithText(FilledButton, 'GHI (Space)'));
        await tester.pumpAndSettle();

        // Initially at line 1 ("Câu 1 / 2")
        expect(find.text('Câu 1 / 2'), findsOneWidget);

        // Tap Space for Word 0 ('Mot')
        clock.positionUs = 1000000;
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();

        // Should still be on Line 1 ('Câu 1 / 2')! Not jumped to Line 2!
        expect(find.text('Câu 1 / 2'), findsOneWidget);
        expect(tester.widget<Text>(find.text('Mot')).style!.fontSize, 15);
        expect(tester.widget<Text>(find.text('hai')).style!.fontSize, 12);

        // Tap Space for Word 1 ('hai')
        clock.positionUs = 2000000;
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();

        // Still on Line 1 ('Câu 1 / 2')!
        expect(find.text('Câu 1 / 2'), findsOneWidget);
        expect(tester.widget<Text>(find.text('hai')).style!.fontSize, 15);
        expect(tester.widget<Text>(find.text('ba')).style!.fontSize, 12);

        // Tap and release Space for Word 2 ('ba' - last token)
        clock.positionUs = 3000000;
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.pump();
        // While space is held on the last word, still on Line 1
        expect(find.text('Câu 1 / 2'), findsOneWidget);

        // Now release space
        clock.positionUs = 4000000;
        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        await tester.pump();

        // Releasing Space must not truncate a sustained final word.
        expect(find.text('Câu 1 / 2'), findsOneWidget);
        expect(controller.project!.lyricLines[0].tokens[2].endUs, isNull);
        clock.positionUs = 6000000;
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();

        // Now that the line is complete, it advances to Line 2 ('Câu 2 / 2')!
        expect(find.text('Câu 2 / 2'), findsOneWidget);

        // Verify that line 0's last word 'ba' was finalized with proper timing!
        final savedLine0 = controller.project!.lyricLines[0];
        expect(savedLine0.tokens[2].startUs, equals(3000000));
        expect(savedLine0.tokens[2].endUs, equals(6000000));
      },
    );

    testWidgets(
      'RecordingOverlay Hold Mode: holding and releasing advances word by word without jumping lines',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final testProject = ProjectModel.create('Test Hold Mode').copyWith(
          settings: const ProjectSettings(
            recordingMode: 'hold',
            inputTimingOffsetMs: 0,
          ),
          lyricLines: const [
            LyricLine(
              id: 'line-0',
              text: 'Mot hai ba',
              actorId: 'male',
              tokens: [
                LyricToken(id: 't-0', index: 0, text: 'Mot'),
                LyricToken(id: 't-1', index: 1, text: 'hai'),
                LyricToken(id: 't-2', index: 2, text: 'ba'),
              ],
            ),
            LyricLine(
              id: 'line-1',
              text: 'Bon nam',
              actorId: 'male',
              tokens: [
                LyricToken(id: 't-3', index: 0, text: 'Bon'),
                LyricToken(id: 't-4', index: 1, text: 'nam'),
              ],
            ),
          ],
        );

        final controller = EditorController(
          serializer: const ProjectSerializer(),
          ffmpeg: FfmpegService(),
          playback: clock,
        );
        controller.project = testProject;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              editorControllerProvider.overrideWith((ref) => controller),
              playbackClockProvider.overrideWith((ref) => clock),
            ],
            child: MaterialApp(
              home: Scaffold(body: RecordingOverlay(onClose: () {})),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Start recording
        await tester.tap(find.widgetWithText(FilledButton, 'GHI (Space)'));
        await tester.pumpAndSettle();

        // Word 0: Hold and release
        clock.positionUs = 1000000;
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.pump();
        clock.positionUs = 1500000;
        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        await tester.pump();

        // Still on Line 1 ('Câu 1 / 2')
        expect(find.text('Câu 1 / 2'), findsOneWidget);

        // Word 1: Hold and release
        clock.positionUs = 2000000;
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.pump();
        clock.positionUs = 2500000;
        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        await tester.pump();

        // Still on Line 1 ('Câu 1 / 2')
        expect(find.text('Câu 1 / 2'), findsOneWidget);

        // Word 2 (last word): Hold and release
        clock.positionUs = 3000000;
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.pump();
        clock.positionUs = 4000000;
        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        await tester.pump();

        // Line 0 is now done -> advances to Line 2 ('Câu 2 / 2')
        expect(find.text('Câu 2 / 2'), findsOneWidget);

        final line0 = controller.project!.lyricLines[0];
        expect(line0.tokens[0].startUs, equals(1000000));
        expect(line0.tokens[0].endUs, equals(1500000));
        expect(line0.tokens[1].startUs, equals(2000000));
        expect(line0.tokens[1].endUs, equals(2500000));
        expect(line0.tokens[2].startUs, equals(3000000));
        expect(line0.tokens[2].endUs, equals(4000000));
      },
    );

    testWidgets(
      'Tap boundaries ignore releases and final word waits for a closing tap',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final testProject = ProjectModel.create('Test Penultimate and Last')
            .copyWith(
              settings: const ProjectSettings(
                recordingMode: 'tap',
                inputTimingOffsetMs: 0,
              ),
              lyricLines: const [
                LyricLine(
                  id: 'line-0',
                  text: 'Mot hai ba',
                  actorId: 'male',
                  tokens: [
                    LyricToken(id: 't-0', index: 0, text: 'Mot'),
                    LyricToken(id: 't-1', index: 1, text: 'hai'),
                    LyricToken(id: 't-2', index: 2, text: 'ba'),
                  ],
                ),
                LyricLine(
                  id: 'line-1',
                  text: 'Bon nam',
                  actorId: 'male',
                  startUs:
                      3500000, // Pre-existing start timestamp on next line!
                  tokens: [
                    LyricToken(
                      id: 't-3',
                      index: 0,
                      text: 'Bon',
                      startUs: 3500000,
                    ),
                    LyricToken(id: 't-4', index: 1, text: 'nam'),
                  ],
                ),
              ],
            );

        final controller = EditorController(
          serializer: const ProjectSerializer(),
          ffmpeg: FfmpegService(),
          playback: clock,
        );
        controller.project = testProject;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              editorControllerProvider.overrideWith((ref) => controller),
              playbackClockProvider.overrideWith((ref) => clock),
            ],
            child: MaterialApp(
              home: Scaffold(body: RecordingOverlay(onClose: () {})),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Start recording
        await tester.tap(find.widgetWithText(FilledButton, 'GHI (Space)'));
        await tester.pumpAndSettle();

        // Word 0: quick tap at 1.0s
        clock.positionUs = 1000000;
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.pump();
        clock.positionUs = 1050000;
        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        await tester.pump();

        // Word 1 (penultimate): held for a bit from 2.0s to 2.6s (600ms)
        clock.positionUs = 2000000;
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.pump();
        clock.positionUs = 2600000;
        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        await tester.pump();

        // Word 2 (last word): starts at 3.0s and held until 5.0s (past line 1's 3.5s!)
        clock.positionUs = 3000000;
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.pump();
        clock.positionUs = 5000000;
        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(controller.project!.lyricLines[0].tokens[2].endUs, isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();

        final line0 = controller.project!.lyricLines[0];
        // The next press closes word 1; release time does not affect tap mode.
        expect(line0.tokens[1].startUs, equals(2000000));
        expect(line0.tokens[1].endUs, equals(3000000));

        // Word 2 should be full 2.0s duration (ends at 5.0s, NOT truncated to 3.49s)!
        expect(line0.tokens[2].startUs, equals(3000000));
        expect(line0.tokens[2].endUs, equals(5000000));
      },
    );

    testWidgets(
      'WaveformTimeline zooms in with 2-finger trackpad pinch gesture on timeline',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final clock = FakePlaybackClock();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1000,
                height: 250,
                child: WaveformTimeline(
                  clock: clock,
                  durationUs: 30000000,
                  waveform: null,
                  project: ProjectModel.create('Pinch test'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('1.0×'), findsOneWidget);

        // Send trackpad pan/zoom events over the timeline multi-track area (x=500, y=100)
        await tester.sendEventToBinding(
          const PointerPanZoomStartEvent(
            position: Offset(500, 100),
          ),
        );
        await tester.sendEventToBinding(
          const PointerPanZoomUpdateEvent(
            position: Offset(500, 100),
            scale: 2.5,
          ),
        );
        await tester.sendEventToBinding(
          const PointerPanZoomEndEvent(
            position: Offset(500, 100),
          ),
        );
        await tester.pump();

        expect(find.text('2.5×'), findsOneWidget);
      },
    );

    testWidgets(
      'WaveformTimeline zooms in with 2-finger trackpad pinch gesture on top toolbar',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final clock = FakePlaybackClock();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1000,
                height: 250,
                child: WaveformTimeline(
                  clock: clock,
                  durationUs: 30000000,
                  waveform: null,
                  project: ProjectModel.create('Toolbar pinch test'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('1.0×'), findsOneWidget);

        // Send trackpad pan/zoom events over top toolbar (x=500, y=14)
        await tester.sendEventToBinding(
          const PointerPanZoomStartEvent(
            position: Offset(500, 14),
          ),
        );
        await tester.sendEventToBinding(
          const PointerPanZoomUpdateEvent(
            position: Offset(500, 14),
            scale: 3.0,
          ),
        );
        await tester.sendEventToBinding(
          const PointerPanZoomEndEvent(
            position: Offset(500, 14),
          ),
        );
        await tester.pump();

        expect(find.text('3.0×'), findsOneWidget);
      },
    );

    testWidgets(
      'WaveformTimeline responds to PointerScaleEvent directly',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final clock = FakePlaybackClock();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1000,
                height: 250,
                child: WaveformTimeline(
                  clock: clock,
                  durationUs: 30000000,
                  waveform: null,
                  project: ProjectModel.create('Scale test'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('1.0×'), findsOneWidget);

        await tester.sendEventToBinding(
          const PointerScaleEvent(
            position: Offset(500, 100),
            scale: 2.0,
          ),
        );
        await tester.pump();

        expect(find.text('2.0×'), findsOneWidget);
      },
    );
  });
}
