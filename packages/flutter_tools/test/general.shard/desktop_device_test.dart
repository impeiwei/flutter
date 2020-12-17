// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:file/memory.dart';
import 'package:flutter_tools/src/application_package.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/desktop_device.dart';
import 'package:flutter_tools/src/devfs.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/project.dart';

import 'package:meta/meta.dart';
import 'package:mockito/mockito.dart';
import 'package:process/process.dart';

import '../src/common.dart';
import '../src/context.dart';

void main() {
  group('Basic info', () {
    testWithoutContext('Category is desktop', () async {
      final FakeDesktopDevice device = setUpDesktopDevice();

      expect(device.category, Category.desktop);
    });

    testWithoutContext('Not an emulator', () async {
      final FakeDesktopDevice device = setUpDesktopDevice();

      expect(await device.isLocalEmulator, false);
      expect(await device.emulatorId, null);
    });

    testWithoutContext('Uses OS name as SDK name', () async {
      final FakeDesktopDevice device = setUpDesktopDevice();

      expect(await device.sdkNameAndVersion, 'Example');
    });
  });

  group('Install', () {
    testWithoutContext('Install checks always return true', () async {
      final FakeDesktopDevice device = setUpDesktopDevice();

      expect(await device.isAppInstalled(null), true);
      expect(await device.isLatestBuildInstalled(null), true);
      expect(device.category, Category.desktop);
    });

    testWithoutContext('Install and uninstall are no-ops that report success', () async {
      final FakeDesktopDevice device = setUpDesktopDevice();
      final FakeApplicationPackage package = FakeApplicationPackage();

      expect(await device.uninstallApp(package), true);
      expect(await device.isAppInstalled(package), true);
      expect(await device.isLatestBuildInstalled(package), true);

      expect(await device.installApp(package), true);
      expect(await device.isAppInstalled(package), true);
      expect(await device.isLatestBuildInstalled(package), true);
      expect(device.category, Category.desktop);
    });
  });

  group('Starting and stopping application', () {
    testWithoutContext('Stop without start is a successful no-op', () async {
      final FakeDesktopDevice device = setUpDesktopDevice();
      final FakeApplicationPackage package = FakeApplicationPackage();

      expect(await device.stopApp(package), true);
    });

    testWithoutContext('Can run from prebuilt application', () async {
      final FileSystem fileSystem = MemoryFileSystem.test();
      final Completer<void> completer = Completer<void>();
      final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
        FakeCommand(
          command: const <String>['debug'],
          stdout: 'Observatory listening on http://127.0.0.1/0\n',
          completer: completer,
        ),
      ]);
      final FakeDesktopDevice device = setUpDesktopDevice(processManager: processManager, fileSystem: fileSystem);
      final String executableName = device.executablePathForDevice(null, BuildMode.debug);
      fileSystem.file(executableName).writeAsStringSync('\n');
      final FakeApplicationPackage package = FakeApplicationPackage();
      final LaunchResult result = await device.startApp(
        package,
        prebuiltApplication: true,
        debuggingOptions: DebuggingOptions.enabled(BuildInfo.debug),
      );

      expect(result.started, true);
      expect(result.observatoryUri, Uri.parse('http://127.0.0.1/0'));
    });

    testWithoutContext('Null executable path fails gracefully', () async {
      final BufferLogger logger = BufferLogger.test();
      final DesktopDevice device = setUpDesktopDevice(nullExecutablePathForDevice: true, logger: logger);
      final FakeApplicationPackage package = FakeApplicationPackage();
      final LaunchResult result = await device.startApp(
        package,
        prebuiltApplication: true,
        debuggingOptions: DebuggingOptions.enabled(BuildInfo.debug),
      );

      expect(result.started, false);
      expect(logger.errorText, contains('Unable to find executable to run'));
    });

    testWithoutContext('stopApp kills process started by startApp', () async {
      final Completer<void> completer = Completer<void>();
      final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
        FakeCommand(
          command: const <String>['debug'],
          stdout: 'Observatory listening on http://127.0.0.1/0\n',
          completer: completer,
        ),
      ]);
      final FakeDesktopDevice device = setUpDesktopDevice(processManager: processManager);
      final FakeApplicationPackage package = FakeApplicationPackage();
      final LaunchResult result = await device.startApp(
        package,
        prebuiltApplication: true,
        debuggingOptions: DebuggingOptions.enabled(BuildInfo.debug),
      );

      expect(result.started, true);
      expect(await device.stopApp(package), true);
    });
  });

  testWithoutContext('startApp supports DebuggingOptions through FLUTTER_ENGINE_SWITCH environment variables', () async {
    final Completer<void> completer = Completer<void>();
    final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
      FakeCommand(
        command: const <String>['debug'],
        stdout: 'Observatory listening on http://127.0.0.1/0\n',
        completer: completer,
        environment: const <String, String>{
          'FLUTTER_ENGINE_SWITCH_1': 'enable-dart-profiling=true',
          'FLUTTER_ENGINE_SWITCH_2': 'enable-background-compilation=true',
          'FLUTTER_ENGINE_SWITCH_3': 'trace-startup=true',
          'FLUTTER_ENGINE_SWITCH_4': 'enable-software-rendering=true',
          'FLUTTER_ENGINE_SWITCH_5': 'skia-deterministic-rendering=true',
          'FLUTTER_ENGINE_SWITCH_6': 'trace-skia=true',
          'FLUTTER_ENGINE_SWITCH_7': 'trace-allowlist=foo,bar',
          'FLUTTER_ENGINE_SWITCH_8': 'trace-systrace=true',
          'FLUTTER_ENGINE_SWITCH_9': 'endless-trace-buffer=true',
          'FLUTTER_ENGINE_SWITCH_10': 'dump-skp-on-shader-compilation=true',
          'FLUTTER_ENGINE_SWITCH_11': 'cache-sksl=true',
          'FLUTTER_ENGINE_SWITCH_12': 'purge-persistent-cache=true',
          'FLUTTER_ENGINE_SWITCH_13': 'enable-checked-mode=true',
          'FLUTTER_ENGINE_SWITCH_14': 'verify-entry-points=true',
          'FLUTTER_ENGINE_SWITCH_15': 'start-paused=true',
          'FLUTTER_ENGINE_SWITCH_16': 'disable-service-auth-codes=true',
          'FLUTTER_ENGINE_SWITCH_17': 'dart-flags=--null_assertions',
          'FLUTTER_ENGINE_SWITCH_18': 'use-test-fonts=true',
          'FLUTTER_ENGINE_SWITCH_19': 'verbose-logging=true',
          'FLUTTER_ENGINE_SWITCHES': '19'
        }
      ),
    ]);
    final FakeDesktopDevice device = setUpDesktopDevice(processManager: processManager);
    final FakeApplicationPackage package = FakeApplicationPackage();
    final LaunchResult result = await device.startApp(
      package,
      prebuiltApplication: true,
      platformArgs: <String, Object>{
        'trace-startup': true,
      },
      debuggingOptions: DebuggingOptions.enabled(
        BuildInfo.debug,
        startPaused: true,
        disableServiceAuthCodes: true,
        dartFlags: '',
        enableSoftwareRendering: true,
        skiaDeterministicRendering: true,
        traceSkia: true,
        traceAllowlist: 'foo,bar',
        traceSystrace: true,
        endlessTraceBuffer: true,
        dumpSkpOnShaderCompilation: true,
        cacheSkSL: true,
        purgePersistentCache: true,
        useTestFonts: true,
        verboseSystemLogs: true,
        nullAssertions: true,
      ),
    );

    expect(result.started, true);
  });

  testWithoutContext('startApp supports DebuggingOptions through FLUTTER_ENGINE_SWITCH environment variables when debugging is disabled', () async {
    final Completer<void> completer = Completer<void>();
    final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
      FakeCommand(
        command: const <String>['debug'],
        stdout: 'Observatory listening on http://127.0.0.1/0\n',
        completer: completer,
        environment: const <String, String>{
          'FLUTTER_ENGINE_SWITCH_1': 'enable-dart-profiling=true',
          'FLUTTER_ENGINE_SWITCH_2': 'enable-background-compilation=true',
          'FLUTTER_ENGINE_SWITCH_3': 'trace-startup=true',
          'FLUTTER_ENGINE_SWITCH_4': 'trace-allowlist=foo,bar',
          'FLUTTER_ENGINE_SWITCH_5': 'cache-sksl=true',
          'FLUTTER_ENGINE_SWITCHES': '5'
        }
      ),
    ]);
    final FakeDesktopDevice device = setUpDesktopDevice(processManager: processManager);
    final FakeApplicationPackage package = FakeApplicationPackage();
    final LaunchResult result = await device.startApp(
      package,
      prebuiltApplication: true,
      platformArgs: <String, Object>{
        'trace-startup': true,
      },
      debuggingOptions: DebuggingOptions.disabled(
        BuildInfo.debug,
        traceAllowlist: 'foo,bar',
        cacheSkSL: true,
      ),
    );

    expect(result.started, true);
  });

  testWithoutContext('Port forwarder is a no-op', () async {
    final FakeDesktopDevice device = setUpDesktopDevice();
    final DevicePortForwarder portForwarder = device.portForwarder;
    final int result = await portForwarder.forward(2);

    expect(result, 2);
    expect(portForwarder.forwardedPorts.isEmpty, true);
  });

  testUsingContext('createDevFSWriter returns a LocalDevFSWriter', () {
    final FakeDesktopDevice device = setUpDesktopDevice();

    expect(device.createDevFSWriter(null, ''), isA<LocalDevFSWriter>());
  });

  testWithoutContext('startApp supports dartEntrypointArgs', () async {
    final Completer<void> completer = Completer<void>();
    final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
      FakeCommand(
        command: const <String>['debug', 'arg1', 'arg2'],
        stdout: 'Observatory listening on http://127.0.0.1/0\n',
        completer: completer
      ),
    ]);
    final FakeDesktopDevice device = setUpDesktopDevice(processManager: processManager);
    final FakeApplicationPackage package = FakeApplicationPackage();
    final LaunchResult result = await device.startApp(
      package,
      prebuiltApplication: true,
      debuggingOptions: DebuggingOptions.enabled(
        BuildInfo.debug,
        dartEntrypointArgs: <String>['arg1', 'arg2']
      ),
    );

    expect(result.started, true);
  });
}

FakeDesktopDevice setUpDesktopDevice({
  FileSystem fileSystem,
  Logger logger,
  ProcessManager processManager,
  OperatingSystemUtils operatingSystemUtils,
  bool nullExecutablePathForDevice = false,
}) {
  return FakeDesktopDevice(
    fileSystem: fileSystem ?? MemoryFileSystem.test(),
    logger: logger ?? BufferLogger.test(),
    processManager: processManager ?? FakeProcessManager.any(),
    operatingSystemUtils: operatingSystemUtils ?? FakeOperatingSystemUtils(),
    nullExecutablePathForDevice: nullExecutablePathForDevice,
  );
}

/// A trivial subclass of DesktopDevice for testing the shared functionality.
class FakeDesktopDevice extends DesktopDevice {
  FakeDesktopDevice({
    @required ProcessManager processManager,
    @required Logger logger,
    @required FileSystem fileSystem,
    @required OperatingSystemUtils operatingSystemUtils,
    this.nullExecutablePathForDevice,
  }) : super(
      'dummy',
      platformType: PlatformType.linux,
      ephemeral: false,
      processManager: processManager,
      logger: logger,
      fileSystem: fileSystem,
      operatingSystemUtils: operatingSystemUtils,
  );

  /// The [mainPath] last passed to [buildForDevice].
  String lastBuiltMainPath;

  /// The [buildInfo] last passed to [buildForDevice].
  BuildInfo lastBuildInfo;

  final bool nullExecutablePathForDevice;

  @override
  String get name => 'dummy';

  @override
  Future<TargetPlatform> get targetPlatform async => TargetPlatform.tester;

  @override
  bool isSupported() => true;

  @override
  bool isSupportedForProject(FlutterProject flutterProject) => true;

  @override
  Future<void> buildForDevice(
    ApplicationPackage package, {
    String mainPath,
    BuildInfo buildInfo,
  }) async {
    lastBuiltMainPath = mainPath;
    lastBuildInfo = buildInfo;
  }

  // Dummy implementation that just returns the build mode name.
  @override
  String executablePathForDevice(ApplicationPackage package, BuildMode buildMode) {
    if (nullExecutablePathForDevice) {
      return null;
    }
    return buildMode == null ? 'null' : getNameForBuildMode(buildMode);
  }
}

class FakeApplicationPackage extends Fake implements ApplicationPackage {}
class FakeOperatingSystemUtils extends Fake implements OperatingSystemUtils {
  @override
  String get name => 'Example';
}
