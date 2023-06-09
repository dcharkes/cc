// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:ffi';
import 'dart:io';

import 'package:cc/cc.dart';
import 'package:config/config.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  final logger = Logger('')..level = Level.ALL;

  test('Cbuilder executable', () async {
    await inTempDir((tempUri) async {
      final packageUri = Directory.current.uri;
      final helloWorldCUri =
          packageUri.resolve('test/hello_world/src/hello_world.c');
      if (!await File.fromUri(helloWorldCUri).exists()) {
        throw Exception('Run the test from the root directory.');
      }
      final executableRelativeUri = Uri.file('hello_world');

      final config = Config(fileParsed: {
        'out_dir': tempUri.path,
      });
      final cbuilder = CBuilder(
        config: config,
        logger: logger,
        sources: [helloWorldCUri],
        executable: executableRelativeUri,
      );
      await cbuilder.run();

      final executableUri = tempUri.resolveUri(executableRelativeUri);
      expect(await File.fromUri(executableUri).exists(), true);
      final result = await Process.run(executableUri.path, []);
      expect(result.exitCode, 0);
      expect(result.stdout, 'Hello world.\n');
    });
  });

  test('Cbuilder dylib', () async {
    await inTempDir((tempUri) async {
      final packageUri = Directory.current.uri;
      final addCUri = packageUri.resolve('test/add/src/add.c');
      final dylibRelativeUri = Uri.file('libadd.so');

      final config = Config(fileParsed: {
        'out_dir': tempUri.path,
      });

      final cbuilder = CBuilder(
        config: config,
        logger: logger,
        sources: [addCUri],
        dynamicLibrary: dylibRelativeUri,
      );
      await cbuilder.run();

      final dylibUri = tempUri.resolveUri(dylibRelativeUri);
      final dylib = DynamicLibrary.open(dylibUri.path);
      final add = dylib.lookupFunction<Int32 Function(Int32, Int32),
          int Function(int, int)>('add');
      expect(add(1, 2), 3);
    });
  });
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
