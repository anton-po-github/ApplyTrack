import 'dart:async';

import 'package:apply_track/core/notifications/local_notification_scheduler.dart';
import 'package:apply_track/core/notifications/noop_notification_scheduler.dart';
import 'package:apply_track/core/notifications/notification_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Only Android and iOS show scheduled notifications. The web (browsers
/// cannot schedule) and desktop get the no-op class. Tests replace this
/// provider with a fake.
final Provider<NotificationScheduler> notificationSchedulerProvider =
    Provider<NotificationScheduler>((ref) {
      final supported =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      if (!supported) {
        return const NoopNotificationScheduler();
      }
      final scheduler = LocalNotificationScheduler();
      ref.onDispose(() => unawaited(scheduler.dispose()));
      return scheduler;
    });
