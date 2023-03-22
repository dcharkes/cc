// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

/// A task that when run executes a process.
class RunProcess {
  final String executable;
  final List<String> arguments;
  final Uri? workingDirectory;
  final Map<String, String>? environment;
  final bool includeParentEnvironment;
  final bool throwOnFailure;

  RunProcess({
    required this.executable,
    this.arguments = const [],
    this.workingDirectory,
    this.environment,
    this.includeParentEnvironment = true,
    this.throwOnFailure = true,
  });

  String get commandString {
    final printWorkingDir =
        workingDirectory != null && workingDirectory != Directory.current.uri;
    return [
      if (printWorkingDir) '(cd ${workingDirectory!.path};',
      ...?environment?.entries.map((entry) => '${entry.key}=${entry.value}'),
      executable,
      ...arguments.map((a) => a.contains(' ') ? "'$a'" : a),
      if (printWorkingDir) ')',
    ].join(' ');
  }

  Future<void> run({Logger? logger}) async {
    final workingDirectoryString = workingDirectory?.toFilePath();

    logger?.info('Running `$commandString`.');
    final process = await Process.start(
      executable,
      arguments,
      runInShell: true,
      workingDirectory: workingDirectoryString,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
    ).then((process) {
      process.stdout
          .transform(utf8.decoder)
          .forEach((s) => logger?.fine('  $s'));
      process.stderr
          .transform(utf8.decoder)
          .forEach((s) => logger?.severe('  $s'));
      return process;
    });
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      final message =
          'Command `$commandString` failed with exit code $exitCode.';
      logger?.severe(message);
      if (throwOnFailure) {
        throw Exception(message);
      }
    }
    logger?.fine('Command `$commandString` done.');
  }
}
