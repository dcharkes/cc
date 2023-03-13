// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:cc/src/target.dart';
import 'package:config/config.dart';
import 'package:native_toolchain/native_toolchain.dart';
import 'package:task_runner/task_runner.dart';

class CompilerResolver implements ToolResolver {
  final Config config;

  CompilerResolver({
    required this.config,
  });

  @override
  Future<List<ToolInstance>> resolve({
    TaskRunner? taskRunner,
  }) async {
    final tool = selectCompiler();
    ToolInstance? result;
    result ??= await _tryLoadCompilerFromConfig(tool, _configKeyCC,
        taskRunner: taskRunner);
    result ??= await _tryLoadCompilerFromConfig(
        tool, _configKeyNativeToolchainClang,
        taskRunner: taskRunner);
    result ??=
        await _tryLoadCompilerFromNativeToolchain(tool, taskRunner: taskRunner);

    if (result != null) {
      return [result];
    }
    const errorMessage = 'No C compiler found.';
    taskRunner?.logger.severe(errorMessage);
    throw Exception(errorMessage);
  }

  /// Select the right compiler for cross compiling to the specified target.
  Tool selectCompiler() {
    final target = config.getString('target') ?? Target.current();
    switch (target) {
      case Target.linuxArm:
        return armLinuxGnueabihfGcc;
      case Target.linuxArm64:
        return aarch64LinuxGnuGcc;
      case Target.linuxIA32:
        return i686LinuxGnuGcc;
      case Target.linuxX64:
        return clang;
      case Target.androidArm:
      case Target.androidArm64:
      case Target.androidIA32:
      case Target.androidX64:
        return androidNdkClang;
    }
    throw Exception('No tool available for target: $target.');
  }

  /// Provided by launchers.
  static const _configKeyCC = 'cc';

  /// Provided by package:native_toolchain.
  static const _configKeyNativeToolchainClang = 'deps.native_toolchain.clang';

  Future<ToolInstance?> _tryLoadCompilerFromConfig(
    Tool tool,
    String configKey, {
    TaskRunner? taskRunner,
  }) async {
    final configCcUri = config.getPath(_configKeyCC);
    if (configCcUri != null) {
      if (await File.fromUri(configCcUri).exists()) {
        taskRunner?.logger.finer(
            'Using compiler ${configCcUri.path} from config[$_configKeyCC].');
        return ToolInstance(tool: tool, uri: configCcUri);
      } else {
        taskRunner?.logger.warning(
            'Compiler ${configCcUri.path} from config[$_configKeyCC] does not exist.');
      }
    }
    return null;
  }

  /// If a build is invoked
  Future<ToolInstance?> _tryLoadCompilerFromNativeToolchain(
    Tool tool, {
    TaskRunner? taskRunner,
  }) async {
    final resolved = (await tool.defaultResolver!.resolve())
        .where((i) => i.tool == tool)
        .toList()
      ..sort();
    if (resolved.isEmpty) {
      taskRunner?.logger
          .warning('Clang could not be found by package:native_toolchain.');
      return null;
    }
    return resolved.last;
  }

  Future<Uri> resolveLinker(Uri compiler, {TaskRunner? taskRunner}) async {
    if (compiler.pathSegments.last == 'clang') {
      final lld = compiler.resolve('lld');
      if (await File.fromUri(lld).exists()) {
        return lld;
      }
    }
    const errorMessage = 'No native linker found.';
    taskRunner?.logger.severe(errorMessage);
    throw Exception(errorMessage);
  }
}

final i686LinuxGnuGcc = Tool(
  name: 'i686-linux-gnu-gcc',
  defaultResolver: PathToolResolver(toolName: 'i686-linux-gnu-gcc'),
);

final armLinuxGnueabihfGcc = Tool(
  name: 'arm-linux-gnueabihf-gcc',
  defaultResolver: PathToolResolver(toolName: 'arm-linux-gnueabihf-gcc'),
);

final aarch64LinuxGnuGcc = Tool(
  name: 'aarch64-linux-gnu-gcc',
  defaultResolver: PathToolResolver(toolName: 'aarch64-linux-gnu-gcc'),
);
