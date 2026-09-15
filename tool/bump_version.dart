// ignore_for_file: avoid_print

import 'dart:io';

void main(List<String> args) {
  final modeArg = args.isNotEmpty ? args[0].toLowerCase() : 'auto';
  final isDryRun = args.contains('--dry-run');

  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('Error: pubspec.yaml not found.');
    exit(1);
  }

  final content = pubspecFile.readAsStringSync();
  final versionRegex = RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?', multiLine: true);
  final match = versionRegex.firstMatch(content);

  if (match == null) {
    stderr.writeln('Error: Could not parse version in pubspec.yaml.');
    exit(1);
  }

  int major = int.parse(match.group(1)!);
  int minor = int.parse(match.group(2)!);
  int patch = int.parse(match.group(3)!);
  int build = int.parse(match.group(4) ?? '0');

  print('Current version: $major.$minor.$patch+$build');

  String bumpType = modeArg;
  if (bumpType == 'auto') {
    bumpType = determineBumpTypeFromGit();
  }

  print('Applying bump type: $bumpType');

  switch (bumpType) {
    case 'major':
      major += 1;
      minor = 0;
      patch = 0;
      break;
    case 'minor':
      minor += 1;
      patch = 0;
      break;
    case 'patch':
    default:
      patch += 1;
      break;
  }

  build += 1;

  final newVersion = '$major.$minor.$patch';
  final fullVersion = '$newVersion+$build';
  final tagName = 'v$newVersion';

  print('Next version: $fullVersion (tag: $tagName)');

  if (!isDryRun) {
    final updatedContent = content.replaceFirst(
      versionRegex,
      'version: $fullVersion',
    );
    pubspecFile.writeAsStringSync(updatedContent);
    print('Updated pubspec.yaml with version: $fullVersion');
  } else {
    print('[Dry-run] Skipped writing to pubspec.yaml');
  }

  // Export to GitHub Actions environment if running in CI
  final githubOutput = Platform.environment['GITHUB_OUTPUT'];
  if (githubOutput != null && File(githubOutput).existsSync()) {
    final file = File(githubOutput);
    file.writeAsStringSync(
      'version=$newVersion\n'
      'build_number=$build\n'
      'full_version=$fullVersion\n'
      'tag_name=$tagName\n'
      'bump_type=$bumpType\n',
      mode: FileMode.append,
    );
    print('Exported variables to GITHUB_OUTPUT.');
  }
}

String determineBumpTypeFromGit() {
  try {
    // Check latest tag
    final tagResult = Process.runSync('git', ['describe', '--tags', '--abbrev=0']);
    final latestTag = tagResult.exitCode == 0 ? (tagResult.stdout as String).trim() : null;

    final List<String> gitLogArgs;
    if (latestTag != null && latestTag.isNotEmpty) {
      gitLogArgs = ['log', '$latestTag..HEAD', '--pretty=format:%B---COMMIT_SEP---'];
    } else {
      gitLogArgs = ['log', '-n', '20', '--pretty=format:%B---COMMIT_SEP---'];
    }

    final logResult = Process.runSync('git', gitLogArgs);
    if (logResult.exitCode != 0) {
      return 'patch';
    }

    final commits = (logResult.stdout as String).split('---COMMIT_SEP---');
    bool hasBreaking = false;
    bool hasFeat = false;

    final breakingRegex = RegExp(r'BREAKING[ -]CHANGE|^[a-zA-Z]+(\([^\)]+\))?!:', multiLine: true);
    final featRegex = RegExp(r'^feat(\([^\)]+\))?:', multiLine: true);

    for (final commit in commits) {
      final trimmed = commit.trim();
      if (trimmed.isEmpty) continue;

      if (breakingRegex.hasMatch(trimmed)) {
        hasBreaking = true;
        break;
      }
      if (featRegex.hasMatch(trimmed)) {
        hasFeat = true;
      }
    }

    if (hasBreaking) return 'major';
    if (hasFeat) return 'minor';
    return 'patch';
  } catch (e) {
    print('Could not analyze git history: $e. Defaulting to patch bump.');
    return 'patch';
  }
}
