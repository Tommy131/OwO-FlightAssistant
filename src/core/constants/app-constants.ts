/*
 *        _____   _          __  _____   _____   _       _____   _____
 *      /  _  \ | |        / / /  _  \ |  _  \ | |     /  _  \ /  ___|
 *      | | | | | |  __   / /  | | | | | |_| | | |     | | | | | |
 *      | | | | | | /  | / /   | | | | |  _  { | |     | | | | | |   _
 *      | |_| | | |/   |/ /    | |_| | | |_| | | |___  | |_| | | |_| |
 *      \_____/ |___/|___/     \_____/ |_____/ |_____| \_____/ \_____/
 *
 *  Copyright (c) 2023 by OwOTeam-DGMT (OwOBlog).
 * @Author       : HanskiJay
 * @E-Mail       : support@owoblog.com
 * @GitHub       : https://github.com/Tommy131
 */

/**
 * 应用级常量
 *
 * 对应 Flutter 版 `lib/core/constants/app_constants.dart`。
 * Web 版的版本号由构建期注入（package.json → import.meta.env），
 * 不再依赖 package_info_plus。
 */
export const AppConstants = {
  // ========== 应用信息 ==========
  appName: 'OwO! FlightAssistant',
  appPackageName: 'com.owoblog.owo_flight_assistant',
  appVersion: import.meta.env.VITE_APP_VERSION ?? '1.0.3-beta',
  appBuildVersion: import.meta.env.VITE_APP_BUILD ?? '20260330',

  // ========== 资源路径 ==========
  assetIconPath: '/icons/app-icon.png',

  // ========== 开发者信息 ==========
  developerName: 'HanskiJay',
  developerEmail: 'support@owoblog.com',
  githubUsername: 'HanskiJay',
  instagramName: 'jay.jay2045',

  // ========== 外部链接 ==========
  donationUrl: 'https://owoblog.com/donation',
  githubUrl: 'https://github.com/Tommy131',
  githubRepoUrl: 'https://github.com/Tommy131/OwO-FlightAssistant',
  instagramUrl: 'https://instagram.com/jay.jay2045',
  owoServiceUrl: 'https://owoblog.com/service',
  discordInviteUrl: 'https://discord.gg/SjPaKwWW6P',
  telegramUrl: 'https://t.me/HanskiJay',

  // ========== API 配置 ==========
  apiBaseUrl: 'https://owoserver.com/api/v1',
  donationApiEndpoint: '/check-donation/',
  versionCheckUrl: 'https://api.github.com/repos/Tommy131/OwO-FlightAssistant/releases/latest',

  // ========== License ==========
  copyright: '© 2025 HanskiJay. All rights reserved.',
  license: 'CC BY-NC-SA 4.0',
} as const;

/** 完整版本串，例如 `1.0.3-beta+20260330` */
export function fullVersionString(): string {
  return `${AppConstants.appVersion}+${AppConstants.appBuildVersion}`;
}
