import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/config/env_config.dart';
import 'core/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize client storage and credentials
  await EnvConfig.initialize();

  // Initialize local notifications and alarm channels
  await NotificationService.instance.initialize();

  runApp(
    const ProviderScope(
      child: BusAlarmApp(),
    ),
  );
}
