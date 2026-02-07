import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:owo_flight_assistant/apps/data/xplane_apt_dat_parser.dart';

void main() {
  test('Parse airport from apt.dat snippet', () async {
    final tempDir = await Directory.systemTemp.createTemp('apt_dat_test');
    final aptPath = '${tempDir.path}${Platform.pathSeparator}apt.dat';
    final content = '''
I
1300 Version
1 123 1 1 0 ZSSS Shanghai Hongqiao International
100 60.00 1 0 0.25 0 2 1 18L 31.19300000 121.32200000 0.00 0.00 2 0 0 0.00 36R 31.20200000 121.35000000 0.00 0.00 2 0 0 0.00
105 12785 50 ATIS
51 12150 Unicom
99
''';
    await File(aptPath).writeAsString(content);

    final data = await XPlaneAptDatParser.loadAirportFromAptPath(
      icaoCode: 'ZSSS',
      aptPath: aptPath,
    );

    expect(data, isNotNull);
    expect(data!.icaoCode, 'ZSSS');
    expect(data.latitude, closeTo(31.1975, 0.0001));
    expect(data.longitude, closeTo(121.336, 0.0001));
    expect(data.runways.any((r) => r.ident == '18L/36R'), isTrue);
    expect(
      data.frequencies.all.any((f) => f.type == 'ATIS' && f.frequency == 127.85),
      isTrue,
    );
    expect(
      data.frequencies.all.any((f) => f.type == 'UNICOM' && f.frequency == 121.50),
      isTrue,
    );
  });
}
