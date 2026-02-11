/*
 *        _____   _          __  _____   _____   _       _____   _____
 *      /  _  \ | |        / / /  _  \ |  _  \ | |     /  _  \ /  ___|
 *      | | | | | |  __   / /  | | | | | |_| | | |     | | | | | |
 *      | | | | | | /  | / /   | | | | |  _  { | |     | | | | | |   _
 *      | |_| | | |/   |/ /    | |_| | | |_| | | |___  | |_| | | |_| |
 *      \_____/ |___/|___/     \_____/ |_____/ |_____| \_____/ \_____/
 *
 *  Copyright (c) 2023 by OwOTeam-DGMT (OwOBlog).
 * @Date         : 2026-02-10
 * @Author       : HanskiJay
 * @LastEditors  : HanskiJay
 * @LastEditTime : 2026-02-10
 * @E-Mail       : support@owoblog.com
 * @Telegram     : https://t.me/HanskiJay
 * @GitHub       : https://github.com/Tommy131
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:owo_flight_assistant/apps/services/app_core/database_loader.dart';
import 'package:owo_flight_assistant/core/services/persistence/persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DatabaseLoader', () {
    late PersistenceService persistence;
    late DatabaseLoader loader;

    setUp(() async {
      persistence = PersistenceService();
      await persistence.initialize();
      loader = DatabaseLoader(persistence: persistence);
    });

    test('应该正确检测未配置的数据库', () async {
      // 清除所有配置
      await persistence.remove('lnm_nav_data_path');
      await persistence.remove('xplane_nav_data_path');

      final result = await loader.loadAndValidate();

      expect(result.lnmStatus, LoadStatus.notConfigured);
      expect(result.xplaneStatus, LoadStatus.notConfigured);
      expect(result.hasAnyDatabase, false);
    });

    test('应该正确检测不存在的数据库文件', () async {
      // 设置无效路径
      await persistence.setString('lnm_nav_data_path', '/invalid/path.sqlite');
      await persistence.setString('xplane_nav_data_path', '/invalid/path.dat');

      final result = await loader.loadAndValidate();

      expect(result.lnmStatus, LoadStatus.fileNotFound);
      expect(result.xplaneStatus, LoadStatus.fileNotFound);
      expect(result.hasAnyDatabase, false);
    });

    test('getStatusMessage 应该返回正确的状态描述', () async {
      await persistence.remove('lnm_nav_data_path');
      await persistence.remove('xplane_nav_data_path');

      final result = await loader.loadAndValidate();
      final message = result.getStatusMessage();

      expect(message, contains('未配置任何数据库'));
    });

    test('getShortStatusMessage 应该返回简短描述', () async {
      await persistence.remove('lnm_nav_data_path');
      await persistence.remove('xplane_nav_data_path');

      final result = await loader.loadAndValidate();
      final message = result.getShortStatusMessage();

      expect(message, equals('未配置数据库'));
    });
  });
}
