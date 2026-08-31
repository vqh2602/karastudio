abstract interface class EditorCommand {
  String get description;
  void execute();
  void undo();
}

class CallbackCommand implements EditorCommand {
  CallbackCommand({
    required this.description,
    required this.onExecute,
    required this.onUndo,
  });

  @override
  final String description;
  final void Function() onExecute;
  final void Function() onUndo;

  @override
  void execute() => onExecute();

  @override
  void undo() => onUndo();
}

class UndoRedoManager {
  UndoRedoManager({this.capacity = 100});

  final int capacity;
  final List<EditorCommand> _undoStack = [];
  final List<EditorCommand> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  String? get undoDescription => canUndo ? _undoStack.last.description : null;
  String? get redoDescription => canRedo ? _redoStack.last.description : null;

  void execute(EditorCommand command) {
    command.execute();
    _undoStack.add(command);
    _redoStack.clear();
    if (_undoStack.length > capacity) _undoStack.removeAt(0);
  }

  void undo() {
    if (!canUndo) return;
    final command = _undoStack.removeLast();
    command.undo();
    _redoStack.add(command);
  }

  void redo() {
    if (!canRedo) return;
    final command = _redoStack.removeLast();
    command.execute();
    _undoStack.add(command);
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
