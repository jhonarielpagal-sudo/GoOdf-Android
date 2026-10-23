// Field definitions that drive the editing forms. Key names are the ones used
// by GrandOrgue organ definition files.

enum FieldKind { text, integer, decimal, yesNo, choice }

class FieldDef {
  final String key;
  final String label;
  final FieldKind kind;

  /// Value shown (and used by GrandOrgue) when the key is not in the file.
  final String def;

  /// For [FieldKind.choice]: pairs of [value, label].
  final List<List<String>> options;

  /// Text fields that should use the full width.
  final bool wide;

  final String? help;

  const FieldDef(
    this.key,
    this.label,
    this.kind, {
    this.def = '',
    this.options = const [],
    this.wide = false,
    this.help,
  });
}

const List<List<String>> kFunctionOptions = [
  ['Input', 'Input'],
  ['And', 'And'],
  ['Or', 'Or'],
  ['Xor', 'Xor'],
  ['Nand', 'Nand'],
  ['Nor', 'Nor'],
  ['Xnor', 'Xnor'],
];

const List<List<String>> kGcStateOptions = [
  ['-1', 'Not changed'],
  ['0', 'Off'],
  ['1', 'On'],
];

// --- [Organ] ---------------------------------------------------------------

const List<FieldDef> kOrganInfoFields = [
  FieldDef('ChurchName', 'Church name', FieldKind.text, wide: true),
  FieldDef('ChurchAddress', 'Church address', FieldKind.text, wide: true),
  FieldDef('OrganBuilder', 'Organ builder', FieldKind.text, wide: true),
  FieldDef('OrganBuildDate', 'Organ build date', FieldKind.text, wide: true),
  FieldDef('OrganComments', 'Organ comments', FieldKind.text, wide: true),
  FieldDef('RecordingDetails', 'Recording details', FieldKind.text, wide: true),
  FieldDef('InfoFilename', 'Organ info file', FieldKind.text, wide: true),
];

const List<FieldDef> kOrganBehaviourFields = [
  FieldDef('DivisionalsStoreIntermanualCouplers',
      'Divisionals store intermanual couplers', FieldKind.yesNo,
      def: 'Y'),
  FieldDef('DivisionalsStoreIntramanualCouplers',
      'Divisionals store intramanual couplers', FieldKind.yesNo,
      def: 'Y'),
  FieldDef('DivisionalsStoreTremulants', 'Divisionals store tremulants',
      FieldKind.yesNo,
      def: 'Y'),
  FieldDef('GeneralsStoreDivisionalCouplers',
      'Generals store divisional couplers', FieldKind.yesNo,
      def: 'Y'),
  FieldDef('CombinationsStoreNonDisplayedDrawstops',
      'Combinations store non displayed drawstops', FieldKind.yesNo,
      def: 'Y'),
  FieldDef('AmplitudeLevel', 'Amplitude level', FieldKind.decimal, def: '100'),
  FieldDef('Gain', 'Gain', FieldKind.decimal, def: '0'),
  FieldDef('PitchTuning', 'Pitch tuning', FieldKind.decimal, def: '0'),
  FieldDef('PitchCorrection', 'Pitch correction', FieldKind.decimal, def: '0'),
  FieldDef('TrackerDelay', 'Tracker delay', FieldKind.integer, def: '0'),
];

/// Settings of the built-in default panel (used when no panel images are given).
const List<FieldDef> kOrganPanelFields = [
  FieldDef('DispScreenSizeHoriz', 'Screen width', FieldKind.integer,
      def: '1024'),
  FieldDef('DispScreenSizeVert', 'Screen height', FieldKind.integer,
      def: '768'),
  FieldDef('DispDrawstopCols', 'Drawstop columns', FieldKind.integer,
      def: '10'),
  FieldDef('DispDrawstopRows', 'Drawstop rows', FieldKind.integer, def: '4'),
  FieldDef('DispButtonCols', 'Button columns', FieldKind.integer, def: '10'),
  FieldDef('DispExtraButtonRows', 'Extra button rows', FieldKind.integer,
      def: '0'),
  FieldDef('DispExtraDrawstopRows', 'Extra drawstop rows', FieldKind.integer,
      def: '0'),
  FieldDef('DispExtraDrawstopCols', 'Extra drawstop columns',
      FieldKind.integer,
      def: '0'),
  FieldDef('DispPairDrawstopCols', 'Pair drawstop columns', FieldKind.yesNo,
      def: 'Y'),
  FieldDef('DispDrawstopColsOffset', 'Offset drawstop columns',
      FieldKind.yesNo,
      def: 'N'),
  FieldDef('DispButtonsAboveManuals', 'Buttons above manuals',
      FieldKind.yesNo,
      def: 'Y'),
  FieldDef('DispExtraPedalButtonRow', 'Extra pedal button row',
      FieldKind.yesNo,
      def: 'N'),
  FieldDef('DispTrimAboveManuals', 'Trim above manuals', FieldKind.yesNo,
      def: 'Y'),
  FieldDef('DispTrimBelowManuals', 'Trim below manuals', FieldKind.yesNo,
      def: 'Y'),
];

// --- [Manual###] -----------------------------------------------------------

const List<FieldDef> kManualFields = [
  FieldDef('Name', 'Manual name', FieldKind.text, wide: true),
  FieldDef('NumberOfLogicalKeys', 'Number of logical keys', FieldKind.integer,
      def: '61'),
  FieldDef('FirstAccessibleKeyLogicalKeyNumber',
      'First accessible key (logical number)', FieldKind.integer,
      def: '1'),
  FieldDef('FirstAccessibleKeyMIDINoteNumber',
      'First accessible key (MIDI note)', FieldKind.integer,
      def: '36'),
  FieldDef('NumberOfAccessibleKeys', 'Number of accessible keys',
      FieldKind.integer,
      def: '61'),
  FieldDef('MIDIInputNumber', 'MIDI input number', FieldKind.integer,
      def: '0'),
  FieldDef('Displayed', 'Displayed on panel', FieldKind.yesNo, def: 'Y'),
];

// --- [Stop###] -------------------------------------------------------------

const List<FieldDef> kStopFields = [
  FieldDef('Name', 'Stop name', FieldKind.text, wide: true),
  FieldDef('Function', 'Function', FieldKind.choice,
      def: 'Input', options: kFunctionOptions),
  FieldDef('Displayed', 'Displayed on panel', FieldKind.yesNo, def: 'Y'),
  FieldDef('DisplayInInvertedState', 'Display in inverted state',
      FieldKind.yesNo,
      def: 'N'),
  FieldDef('DefaultToEngaged', 'Default to engaged', FieldKind.yesNo,
      def: 'N'),
  FieldDef('GCState', 'State when GC is activated', FieldKind.choice,
      def: '0', options: kGcStateOptions),
  FieldDef('StoreInDivisional', 'Store in divisional', FieldKind.yesNo,
      def: 'Y'),
  FieldDef('StoreInGeneral', 'Store in generals', FieldKind.yesNo, def: 'Y'),
  FieldDef('FirstAccessiblePipeLogicalKeyNumber',
      'First accessible pipe (logical key number)', FieldKind.integer,
      def: '1'),
  FieldDef('NumberOfAccessiblePipes', 'Number of accessible pipes',
      FieldKind.integer,
      def: '61'),
  FieldDef('AmplitudeLevel', 'Amplitude level', FieldKind.decimal, def: '100'),
];

// --- [Rank###] -------------------------------------------------------------

const List<FieldDef> kRankFields = [
  FieldDef('Name', 'Rank name', FieldKind.text, wide: true),
  FieldDef('FirstMidiNoteNumber', 'First MIDI note', FieldKind.integer,
      def: '36'),
  FieldDef('NumberOfLogicalPipes', 'Number of logical pipes',
      FieldKind.integer,
      def: '61'),
  FieldDef('HarmonicNumber', 'Harmonic number', FieldKind.decimal, def: '8'),
  FieldDef('PitchTuning', 'Pitch tuning', FieldKind.decimal, def: '0'),
  FieldDef('PitchCorrection', 'Pitch correction', FieldKind.decimal,
      def: '0'),
  FieldDef('AmplitudeLevel', 'Amplitude level', FieldKind.decimal,
      def: '100'),
  FieldDef('Gain', 'Gain', FieldKind.decimal, def: '0'),
  FieldDef('TrackerDelay', 'Tracker delay', FieldKind.integer, def: '0'),
  FieldDef('MinVelocityVolume', 'Min velocity volume', FieldKind.decimal,
      def: '100'),
  FieldDef('MaxVelocityVolume', 'Max velocity volume', FieldKind.decimal,
      def: '100'),
  FieldDef('Percussive', 'Percussive', FieldKind.yesNo, def: 'N'),
  FieldDef('AcceptsRetuning', 'Accepts retuning', FieldKind.yesNo, def: 'Y'),
  FieldDef('IsIndependentRelease', 'Independent release', FieldKind.yesNo,
      def: 'N'),
];

// --- [WindchestGroup###] ---------------------------------------------------

const List<FieldDef> kWindchestFields = [
  FieldDef('Name', 'Windchest group name', FieldKind.text, wide: true),
];

// --- [Enclosure###] --------------------------------------------------------

const List<FieldDef> kEnclosureFields = [
  FieldDef('Name', 'Enclosure name', FieldKind.text, wide: true),
  FieldDef('AmpMinimumLevel', 'Amplitude minimum level', FieldKind.integer,
      def: '0'),
  FieldDef('Displayed', 'Displayed on panel', FieldKind.yesNo, def: 'Y'),
  FieldDef('MIDIInputNumber', 'MIDI input number', FieldKind.integer,
      def: '0'),
];

// --- [Tremulant###] --------------------------------------------------------

const List<FieldDef> kTremulantFields = [
  FieldDef('Name', 'Tremulant name', FieldKind.text, wide: true),
  FieldDef('Function', 'Function', FieldKind.choice,
      def: 'Input', options: kFunctionOptions),
  FieldDef('DisplayInInvertedState', 'Display in inverted state',
      FieldKind.yesNo,
      def: 'N'),
  FieldDef('Displayed', 'Displayed on panel', FieldKind.yesNo, def: 'Y'),
  FieldDef('DefaultToEngaged', 'Default to engaged', FieldKind.yesNo,
      def: 'N'),
  FieldDef('GCState', 'State when GC is activated', FieldKind.choice,
      def: '0', options: kGcStateOptions),
  FieldDef('StoreInDivisional', 'Store in divisional', FieldKind.yesNo,
      def: 'Y'),
  FieldDef('StoreInGeneral', 'Store in generals', FieldKind.yesNo, def: 'Y'),
  FieldDef('TremulantType', 'Type of tremulant', FieldKind.choice,
      def: 'Synth',
      options: [
        ['Synth', 'Synth'],
        ['Wave', 'Wave'],
      ]),
  FieldDef('Period', 'Period', FieldKind.integer, def: '160'),
  FieldDef('StartRate', 'Start rate', FieldKind.integer, def: '8'),
  FieldDef('StopRate', 'Stop rate', FieldKind.integer, def: '8'),
  FieldDef('AmpModDepth', 'Amplitude modulation depth', FieldKind.integer,
      def: '18'),
];

// --- [Switch###] -----------------------------------------------------------

const List<FieldDef> kSwitchFields = [
  FieldDef('Name', 'Switch name', FieldKind.text, wide: true),
  FieldDef('DisplayInInvertedState', 'Display in inverted state',
      FieldKind.yesNo,
      def: 'N'),
  FieldDef('Displayed', 'Displayed on panel', FieldKind.yesNo, def: 'Y'),
  FieldDef('DefaultToEngaged', 'Default to engaged', FieldKind.yesNo,
      def: 'N'),
  FieldDef('GCState', 'State when GC is activated', FieldKind.choice,
      def: '0', options: kGcStateOptions),
  FieldDef('StoreInDivisional', 'Store in divisional', FieldKind.yesNo,
      def: 'Y'),
  FieldDef('StoreInGeneral', 'Store in generals', FieldKind.yesNo, def: 'Y'),
];

// --- [Coupler###] ----------------------------------------------------------

const List<FieldDef> kCouplerFields = [
  FieldDef('Name', 'Coupler name', FieldKind.text, wide: true),
  FieldDef('Function', 'Function', FieldKind.choice,
      def: 'Input', options: kFunctionOptions),
  FieldDef('Displayed', 'Displayed on panel', FieldKind.yesNo, def: 'Y'),
  FieldDef('DisplayInInvertedState', 'Display in inverted state',
      FieldKind.yesNo,
      def: 'N'),
  FieldDef('DefaultToEngaged', 'Default to engaged', FieldKind.yesNo,
      def: 'N'),
  FieldDef('GCState', 'State when GC is activated', FieldKind.choice,
      def: '0', options: kGcStateOptions),
  FieldDef('StoreInDivisional', 'Store in divisional', FieldKind.yesNo,
      def: 'Y'),
  FieldDef('StoreInGeneral', 'Store in generals', FieldKind.yesNo, def: 'Y'),
  FieldDef('UnisonOff', 'Unison off', FieldKind.yesNo, def: 'N'),
  FieldDef('DestinationKeyshift', 'Destination key shift', FieldKind.integer,
      def: '0'),
  FieldDef('CoupleToSubsequentUnisonIntermanualCouplers',
      'Couple to subsequent unison intermanual couplers', FieldKind.yesNo,
      def: 'N'),
  FieldDef('CoupleToSubsequentUpwardIntermanualCouplers',
      'Couple to subsequent upward intermanual couplers', FieldKind.yesNo,
      def: 'N'),
  FieldDef('CoupleToSubsequentDownwardIntermanualCouplers',
      'Couple to subsequent downward intermanual couplers', FieldKind.yesNo,
      def: 'N'),
  FieldDef('CoupleToSubsequentUpwardIntramanualCouplers',
      'Couple to subsequent upward intramanual couplers', FieldKind.yesNo,
      def: 'N'),
  FieldDef('CoupleToSubsequentDownwardIntramanualCouplers',
      'Couple to subsequent downward intramanual couplers', FieldKind.yesNo,
      def: 'N'),
];
