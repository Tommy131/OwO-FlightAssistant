/*
 *        _____   _          __  _____   _____   _       _____   _____
 *      /  _  \ | |        / / /  _  \ |  _  \ | |     /  _  \ /  ___|
 *      | | | | | |  __   / /  | | | | | |_| | | |     | | | | | |
 *      | | | | | | /  | / /   | | | | |  _  { | |     | | | | | |   _
 *      | |_| | | |/   |/ /    | |_| | | |_| | | |___  | |_| | | |_| |
 *      \_____/ |___/|___/     \_____/ |_____/ |_____| \_____/ \_____/
 *
 *  Copyright (c) 2023 by OwOTeam-DGMT (OwOBlog).
 * @Date         : 2025-10-22
 * @Author       : HanskiJay
 * @LastEditors  : HanskiJay
 * @LastEditTime : 2025-10-22
 * @E-Mail       : support@owoblog.com
 * @Telegram     : https://t.me/HanskiJay
 * @GitHub       : https://github.com/Tommy131
 */
class AppConstants {
  // 私有构造函数，防止实例化
  AppConstants._();

  // ========== 应用信息 ==========
  static const String appName = 'OwO! FlightAssistant';
  static const String appPackageName = 'com.owoblog.owo_flight_assistant';
  static const String appVersion = '0.0.1';

  // ========== 开发者信息 ==========
  static const String developerName = 'HanskiJay';
  static const String developerEmail = 'support@owoblog.com';
  static const String githubUsername = 'HanskiJay';
  static const String instagramName = 'jay.jay2045';

  // ========== 外部链接 ==========
  static const String donationUrl = 'https://owoblog.com/donation';
  static const String githubUrl = 'https://github.com/Tommy131';
  static const String instagramUrl = 'https://instagram.com/$instagramName';
  static const String owoServiceUrl = 'https://owoblog.com/service';

  // ========== API 配置 ==========
  static const String apiBaseUrl = 'https://owoserver.com/api/v1';
  static const String donationApiEndpoint = '/check-donation/';

  // ========== License ==========
  static const String copyright = '© 2025 $developerName. All rights reserved.';
  static const String license = 'MIT License';
}
