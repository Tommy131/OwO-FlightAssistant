import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:owo_flight_assistant/apps/data/xplane_apt_dat_parser.dart';

void main() {
  test('Parse airport from apt.dat snippet', () async {
    final tempDir = await Directory.systemTemp.createTemp('apt_dat_test');
    final aptPath = '${tempDir.path}${Platform.pathSeparator}apt.dat';
    final content = '''
I
1100 Version
1 4 Shanghai Hongqiao International
1302 code ZSSS
100 45 2 0 0 0 0 0 0 31.193000 121.322000 31.202000 121.350000 18L 36R
100 45 2 0 0 0 0 0 0 31.195000 121.330000 31.205000 121.358000 18R 36L
1300 127.850 ATIS Shanghai ATIS
99
''';
    await File(aptPath).writeAsString(content);

    final data = await XPlaneAptDatParser.loadAirportFromAptPath(
      icaoCode: 'ZSSS',
      aptPath: aptPath,
    );

    expect(data, isNotNull);
    expect(data!.icaoCode, 'ZSSS');
    expect(data.name.toLowerCase().contains('hongqiao'), isTrue);
    expect(data.runways.isNotEmpty, isTrue);
    expect(
      data.frequencies.all.any((f) => f.type.toUpperCase() == 'ATIS'),
      isTrue,
    );
  });
}
