import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/platform.dart';
import 'services/database.dart';
import 'services/device_info_service.dart';
import 'services/file_transfer_manager.dart';
import 'services/identity_service.dart';
import 'services/network_manager.dart';
import 'services/workspace_manager.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Desktop: take over the window chrome so we can draw our own title bar.
  if (isDesktopWindowing) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1040, 720),
      minimumSize: Size(430, 580),
      center: true,
      title: 'PIM',
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final identity = IdentityService();
  await identity.load();

  final specs = await DeviceInfoService.collect();

  final database = await AppDatabase.open();
  final network = NetworkManager(identity, specs);
  final controller = AppController(identity, network, specs);
  await controller.init();

  final workspaces = WorkspaceManager(identity, network, database);
  final transfers = FileTransferManager(identity, network, workspaces);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppController>.value(value: controller),
        ChangeNotifierProvider<WorkspaceManager>.value(value: workspaces),
        ChangeNotifierProvider<FileTransferManager>.value(value: transfers),
      ],
      child: const PimApp(),
    ),
  );
}
