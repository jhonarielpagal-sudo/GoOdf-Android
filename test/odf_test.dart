import 'package:flutter_test/flutter_test.dart';
import 'package:goodf_mobile/odf/odf_io.dart';

void main() {
  const sample = '''
[Organ]
ChurchName=Test Church ; inline comment
NumberOfManuals=1

; a comment
[Manual001]
Name=Great
NumberOfStops=1
Stop001=1

[Stop001]
Name=Principal 8
Rank001=1
''';

  test('parses sections, keys and strips inline comments', () {
    final doc = OdfParser.parse(sample);
    expect(doc.sections.length, 3);
    expect(doc.find('Organ')!.get('ChurchName'), 'Test Church');
    expect(doc.find('Manual001')!.number, 1);
    expect(doc.types, ['Organ', 'Manual', 'Stop']);
  });

  test('write then parse round-trips the data', () {
    final doc = OdfParser.parse(sample);
    final again = OdfParser.parse(OdfWriter.write(doc));
    expect(again.sections.map((s) => s.name), doc.sections.map((s) => s.name));
    expect(again.find('Stop001')!.get('Name'), 'Principal 8');
  });

  test('addNumbered picks next free number', () {
    final doc = OdfParser.parse(sample);
    final s = doc.addNumbered('Stop');
    expect(s.name, 'Stop002');
  });
}
