import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/core/undo_redo/undo_redo_manager.dart';

void main() {
  test('executes, undoes and redoes a command', () {
    var value = 0;
    final history = UndoRedoManager();
    history.execute(
      CallbackCommand(
        description: 'Increment',
        onExecute: () => value++,
        onUndo: () => value--,
      ),
    );

    expect(value, 1);
    expect(history.canUndo, isTrue);
    history.undo();
    expect(value, 0);
    expect(history.canRedo, isTrue);
    history.redo();
    expect(value, 1);
  });

  test('respects history capacity', () {
    var value = 0;
    final history = UndoRedoManager(capacity: 2);
    for (var index = 0; index < 3; index++) {
      history.execute(
        CallbackCommand(
          description: 'Increment',
          onExecute: () => value++,
          onUndo: () => value--,
        ),
      );
    }
    history.undo();
    history.undo();
    history.undo();
    expect(value, 1);
  });
}
