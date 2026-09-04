import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/project_model.dart';

class ProjectSerializer {
  const ProjectSerializer();

  Future<ProjectModel> load(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Không tìm thấy project.', filePath);
    }
    try {
      final value = jsonDecode(await file.readAsString());
      if (value is! Map<String, Object?>) {
        throw const FormatException('Project không chứa JSON object hợp lệ.');
      }
      return ProjectModel.fromJson(value);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Không thể đọc project: $error');
    }
  }

  Future<void> save(ProjectModel project, String filePath) async {
    final contents = const JsonEncoder.withIndent(
      '  ',
    ).convert(project.toJson());

    // Validate JSON structure in memory before writing to disk
    final check = jsonDecode(contents);
    if (check is! Map || check['id'] != project.id) {
      throw const FormatException('Xác thực cấu trúc project thất bại.');
    }

    final target = File(filePath);
    if (!await target.parent.exists()) {
      try {
        await target.parent.create(recursive: true);
      } catch (_) {}
    }

    await target.writeAsString(contents, flush: true);
  }

  Future<String> autosavePathFor(ProjectModel project) async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'recovery'));
    await directory.create(recursive: true);
    return p.join(directory.path, '${project.id}.autosave.karastudio');
  }

  Future<void> saveRecovery(ProjectModel project) async {
    await save(project, await autosavePathFor(project));
  }

  Future<void> clearRecovery(ProjectModel project) async {
    final file = File(await autosavePathFor(project));
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }
}
