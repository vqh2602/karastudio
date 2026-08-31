import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/editor/editor_controller.dart';
import '../features/editor/editor_page.dart';
import 'theme/editor_theme.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

class KaraStudioApp extends ConsumerStatefulWidget {
  const KaraStudioApp({super.key});

  @override
  ConsumerState<KaraStudioApp> createState() => _KaraStudioAppState();
}

class _KaraStudioAppState extends ConsumerState<KaraStudioApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(editorControllerProvider).initialize());
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KaraStudio',
      themeMode: mode,
      theme: EditorTheme.light(),
      darkTheme: EditorTheme.dark(),
      home: const EditorPage(),
    );
  }
}
