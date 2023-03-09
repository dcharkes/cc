// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:cc/src/compiler_resolver.dart';
import 'package:cc/src/target.dart';
import 'package:config/config.dart';
import 'package:task_runner/task_runner.dart';

class CBuilder implements Task {
  final Config config;
  final List<Uri> sources;
  final List<Uri> includePaths;
  final Uri? executable;
  final Uri? dynamicLibrary;
  final Uri? staticLibrary;
  final Uri outDir;
  final String target;

  CBuilder({
    required this.config,
    this.sources = const [],
    this.includePaths = const [],
    this.executable,
    this.dynamicLibrary,
    this.staticLibrary,
  })  : outDir = config.getPath('out_dir')!,
        target = config.getString('target') ?? Target.current() {
    if ([executable, dynamicLibrary, staticLibrary].whereType<Uri>().length !=
        1) {
      throw ArgumentError(
          'Provide one of executable, dynamicLibrary, or staticLibrary.');
    }
    if (staticLibrary != null) {
      UnimplementedError();
    }
  }

  Uri? _compilerCached;

  Future<Uri> compiler({TaskRunner? taskRunner}) async {
    if (_compilerCached != null) {
      return _compilerCached!;
    }
    final resolver = CompilerResolver(config: config);
    _compilerCached = await resolver.resolveCompiler(taskRunner: taskRunner);
    return _compilerCached!;
  }

  Uri? _linkerCached;

  Future<Uri> linker({TaskRunner? taskRunner}) async {
    if (_linkerCached != null) {
      return _linkerCached!;
    }
    final compiler_ = await compiler(taskRunner: taskRunner);
    final resolver = CompilerResolver(config: config);
    _linkerCached =
        await resolver.resolveLinker(compiler_, taskRunner: taskRunner);
    return _linkerCached!;
  }

  @override
  Future<void> run({TaskRunner? taskRunner}) async {
    final compiler_ = await compiler(taskRunner: taskRunner);

    final task = RunProcess(executable: compiler_.path, arguments: [
      ...sources.map((e) => e.path),
      if (executable != null) ...[
        '-o',
        outDir.resolveUri(executable!).path,
      ],
      if (dynamicLibrary != null) ...[
        '--shared',
        '-o',
        outDir.resolveUri(dynamicLibrary!).path,
      ],
    ]);

    await task.run(taskRunner: taskRunner);
  }
}
