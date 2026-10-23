import 'package:flutter_test/flutter_test.dart';
import 'package:goodf_mobile/odf/odf_io.dart';
import 'package:goodf_mobile/odf/odf_model.dart';
import 'package:goodf_mobile/odf/odf_ops.dart';

const String kSample = r'''
[Organ]
ChurchName=Test
HasPedals=N
NumberOfManuals=1
NumberOfEnclosures=0
NumberOfTremulants=0
NumberOfWindchestGroups=1
NumberOfReversiblePistons=0
NumberOfGenerals=0
NumberOfDivisionalCouplers=0
NumberOfPanels=0
NumberOfRanks=2
NumberOfSwitches=0

[Manual001]
Name=Great
NumberOfLogicalKeys=61
NumberOfStops=2
Stop001=001
Stop002=002
NumberOfCouplers=0
NumberOfSwitches=0
NumberOfTremulants=0

[Stop001]
Name=Principal 8'
NumberOfRanks=1
Rank001=001
Rank001FirstPipeNumber=1
Rank001FirstAccessibleKeyNumber=1
Rank001PipeCount=61

[Stop002]
Name=Flute 4'
NumberOfRanks=1
Rank001=002
Rank001FirstPipeNumber=1
Rank001FirstAccessibleKeyNumber=1
Rank001PipeCount=61

[Rank001]
Name=Principal
NumberOfLogicalPipes=61
WindchestGroup=001
Pipe001=A\a.wav

[Rank002]
Name=Flute
NumberOfLogicalPipes=61
WindchestGroup=001
Pipe001=B\b.wav

[WindchestGroup001]
Name=Main
NumberOfEnclosures=0
NumberOfTremulants=0
''';

void main() {
  test('parse and write round trip', () {
    final doc = OdfParser.parse(kSample);
    expect(doc.sections.length, 7);
    final again = OdfParser.parse(OdfWriter.write(doc));
    expect(again.sections.map((s) => s.name).toList(),
        doc.sections.map((s) => s.name).toList());
    expect(again.find('Rank001')!.get('Pipe001'), r'A\a.wav');
  });

  test('sample file is valid', () {
    expect(validate(OdfParser.parse(kSample)), isEmpty);
  });

  test('deleting a rank renumbers and fixes references', () {
    final doc = OdfParser.parse(kSample);
    deleteSection(doc, doc.find('Rank001')!);
    expect(doc.find('Rank002'), isNull);
    expect(doc.find('Rank001')!.get('Name'), 'Flute');
    expect(doc.find('Stop001')!.get('NumberOfRanks'), '0');
    expect(doc.find('Stop002')!.get('Rank001'), '001');
    expect(doc.find('Organ')!.get('NumberOfRanks'), '1');
    expect(validate(doc), isEmpty);
  });

  test('deleting a stop updates the manual', () {
    final doc = OdfParser.parse(kSample);
    deleteSection(doc, doc.find('Stop001')!);
    final m = doc.find('Manual001')!;
    expect(m.get('NumberOfStops'), '1');
    expect(m.get('Stop001'), '001');
    expect(doc.find('Stop001')!.get('Name'), 'Flute 4\'');
    expect(validate(doc), isEmpty);
  });

  test('adding a stop links it to the manual', () {
    final doc = OdfParser.parse(kSample);
    final no = addStop(doc, doc.find('Manual001')!);
    expect(no, 3);
    expect(doc.find('Manual001')!.get('NumberOfStops'), '3');
    expect(doc.find('Manual001')!.get('Stop003'), '003');
    expect(validate(doc), isEmpty);
  });

  test('import copies stops with their ranks', () {
    final src = OdfParser.parse(kSample);
    final dst = newOrgan();
    addManual(dst);
    final wc = addWindchestGroup(dst, 'Main');
    expect(stopsOfManuals(src).length, 2);
    final log = importItems(dst, src,
        stopNos: [2],
        rankNos: [],
        destManual: 1,
        destWindchest: wc,
        prefix: '..\\X\\');
    expect(log.length, 2);
    expect(dst.find('Rank001')!.get('Name'), 'Flute');
    expect(dst.find('Rank001')!.get('Pipe001'), r'..\X\B\b.wav');
    expect(dst.find('Rank001')!.get('WindchestGroup'), '001');
    final st = dst.find('Stop001')!;
    expect(st.get('Name'), "Flute 4'");
    expect(st.get('Rank001'), '001');
    expect(dst.find('Manual001')!.get('Stop001'), '001');
    expect(validate(dst), isEmpty);
  });

  test('new organ is valid', () {
    expect(validate(newOrgan()), isEmpty);
  });

  test('OdfSection helpers', () {
    final s = OdfSection('Stop012');
    s.set('Name', 'X');
    expect(s.topType, 'Stop');
    expect(s.topNumber, 12);
    expect(s.label, 'X');
  });
}
