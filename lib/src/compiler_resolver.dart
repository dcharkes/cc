// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:config/config.dart';
import 'package:native_toolchain/native_toolchain.dart';
import 'package:task_runner/task_runner.dart';

class CompilerResolver {
  final Config config;

  CompilerResolver({
    required this.config,
  });

  Future<Uri> resolveCompiler({
    TaskRunner? taskRunner,
  }) async {
    Uri? result;
    result ??=
        await _tryLoadCompilerFromConfig(_configKeyCC, taskRunner: taskRunner);
    result ??= await _tryLoadCompilerFromConfig(_configKeyNativeToolchainClang,
        taskRunner: taskRunner);
    result ??=
        await _tryLoadCompilerFromNativeToolchain(taskRunner: taskRunner);

    if (result != null) {
      return result;
    }
    const errorMessage = 'No C compiler found.';
    taskRunner?.logger.severe(errorMessage);
    throw Exception(errorMessage);
  }

  /// Provided by launchers.
  static const _configKeyCC = 'cc';

  /// Provided by package:native_toolchain.
  static const _configKeyNativeToolchainClang = 'deps.native_toolchain.clang';

  Future<Uri?> _tryLoadCompilerFromConfig(
    String configKey, {
    TaskRunner? taskRunner,
  }) async {
    final configCcUri = config.getPath(_configKeyCC);
    if (configCcUri != null) {
      if (await File.fromUri(configCcUri).exists()) {
        taskRunner?.logger.finer(
            'Using compiler ${configCcUri.path} from config[$_configKeyCC].');
        return configCcUri;
      } else {
        taskRunner?.logger.warning(
            'Compiler ${configCcUri.path} from config[$_configKeyCC] does not exist.');
      }
    }
    return null;
  }

  /// If a build is invoked
  Future<Uri?> _tryLoadCompilerFromNativeToolchain({
    TaskRunner? taskRunner,
  }) async {
    try {
      final clang = await SystemTools.clang;
      taskRunner?.logger
          .finer('Using compiler ${clang.path} from package:native_toolchain.');
      return clang.uri;
    } catch (e) {
      taskRunner?.logger
          .warning('Clang could not be found by package:native_toolchain: $e');
    }
    return null;
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
