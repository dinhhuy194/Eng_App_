import 'dart:ui' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

/// Service quản lý Local Notifications
///
/// Chức năng: Nhắc nhở ôn tập Flashcard theo lịch Spaced Repetition
class NotificationService {
  // ── Singleton ──
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ═══════════════════════════════════════════
  //  INIT
  // ═══════════════════════════════════════════

  /// Khởi tạo notifications plugin
  /// Gọi trong main.dart trước khi runApp
  Future<void> init() async {
    if (_initialized) return;

    // Timezone init
    tz.initializeTimeZones();

    // Android settings
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings (cần xin phép)
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Xin quyền trên Android 13+
    await _requestPermissions();

    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Có thể navigate đến ReviewScreen từ đây
    // Cần setup deep link hoặc callback
  }

  // ═══════════════════════════════════════════
  //  REVIEW REMINDER
  // ═══════════════════════════════════════════

  /// Lên lịch nhắc ôn tập cho thời điểm cụ thể
  ///
  /// [id] - ID duy nhất cho notification (dùng hashCode của cardId)
  /// [scheduledAt] - Thời điểm nextReviewAt từ SM-2
  Future<void> scheduleReviewReminder({
    required int id,
    required DateTime scheduledAt,
    String title = '🧠 Đến giờ ôn tập!',
    String body = 'Bạn có flashcard cần ôn. Ôn ngay để không quên!',
  }) async {
    if (!_initialized) await init();

    // Không schedule cho quá khứ
    if (scheduledAt.isBefore(DateTime.now())) return;

    final tzTime = tz.TZDateTime.from(scheduledAt, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'review_reminder', // Channel ID
      'Nhắc ôn tập', // Channel name
      channelDescription: 'Thông báo nhắc nhở ôn tập Flashcard',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF667EEA),
      enableLights: true,
      enableVibration: true,
    );

    const notifDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzTime,
      notificationDetails: notifDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Nhắc ôn tập hàng ngày vào giờ cố định
  ///
  /// Mặc định: 8:00 sáng mỗi ngày
  Future<void> scheduleDailyReminder({
    int hour = 8,
    int minute = 0,
  }) async {
    if (!_initialized) await init();

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Nếu đã qua giờ hôm nay, schedule cho ngày mai
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'daily_reminder',
      'Nhắc học hàng ngày',
      channelDescription: 'Thông báo nhắc nhở học tập hàng ngày',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF667EEA),
    );

    const notifDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
      ),
    );

    await _plugin.zonedSchedule(
      id: 999, // Fixed ID for daily reminder
      title: '📚 Thời gian học tập!',
      body: 'Hãy dành vài phút ôn tập flashcard nhé!',
      scheduledDate: scheduledDate,
      notificationDetails: notifDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Lặp lại hàng ngày
    );
  }

  // ═══════════════════════════════════════════
  //  INSTANT NOTIFICATION (for testing)
  // ═══════════════════════════════════════════

  /// Hiển thị notification ngay lập tức (dùng để test)
  Future<void> showInstant({
    int id = 0,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'instant',
      'Thông báo',
      channelDescription: 'Thông báo tức thì',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notifDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );

    await _plugin.show(id: id, title: title, body: body, notificationDetails: notifDetails);
  }

  // ═══════════════════════════════════════════
  //  CANCEL
  // ═══════════════════════════════════════════

  /// Hủy notification cụ thể
  Future<void> cancel(int id) async {
    await _plugin.cancel(id: id);
  }

  /// Hủy tất cả notifications
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Hủy nhắc ôn hàng ngày
  Future<void> cancelDailyReminder() async {
    await _plugin.cancel(id: 999);
  }
}
