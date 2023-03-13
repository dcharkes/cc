// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:cc/cc.dart';
import 'package:cc/src/target.dart';
import 'package:config/config.dart';
import 'package:logging/logging.dart';
import 'package:task_runner/task_runner.dart';
import 'package:test/test.dart';

void main() {
  final taskRunner = TaskRunner(logLevel: Level.ALL);

  const targets = [
    Target.linuxArm,
    Target.linuxArm64,
    Target.linuxIA32,
    Target.linuxX64
  ];

  const readElfMachine = {
    Target.linuxArm: 'ARM',
    Target.linuxArm64: 'AArch64',
    Target.linuxIA32: 'Intel 80386',
    Target.linuxX64: 'Advanced Micro Devices X86-64',
  };

  for (final target in targets) {
    test('Cbuilder dylib linux $target', () async {
      await inTempDir((tempUri) async {
        final packageUri = Directory.current.uri;
        final addCUri = packageUri.resolve('test/add/src/add.c');
        final dylibRelativeUri = Uri(path: 'libadd.so');

        final config = Config(fileParsed: {
          'out_dir': tempUri.path,
          'target': target,
        });

        final cbuilder = CBuilder(
          config: config,
          sources: [addCUri],
          dynamicLibrary: dylibRelativeUri,
        );
        await cbuilder.run(taskRunner: taskRunner);

        final dylibUri = tempUri.resolveUri(dylibRelativeUri);
        final result = await Process.run('readelf', ['-h', dylibUri.path]);
        expect(result.exitCode, 0);
        final machine = (result.stdout as String)
            .split('\n')
            .firstWhere((e) => e.contains('Machine:'));
        expect(machine, contains(readElfMachine[target]));
        expect(result.exitCode, 0);
      });
    });
  }
}

const keepTempKey = 'KEEP_TEMPORARY_DIRECTORIES';

Future<void> inTempDir(
  Future<void> Function(Uri tempUri) fun, {
  String? prefix,
}) async {
  final tempDir = await Directory.systemTemp.createTemp(prefix);
  try {
    await fun(tempDir.uri);
  } finally {
    if (!Platform.environment.containsKey(keepTempKey) ||
        Platform.environment[keepTempKey]!.isEmpty) {
      await tempDir.delete(recursive: true);
    }
  }
}
