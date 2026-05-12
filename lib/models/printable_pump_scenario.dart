import 'dart:math';

/// Difficulty options for printable worksheets.
enum PrintableWorksheetDifficulty { beginner, mixedBeginnerIntermediate, advanced }

enum PrintableScenarioMode { randomSheet, createScenario }

enum PrintableScenarioType {
  attackLine,
  vehicleFire,
  commercialBuilding,
  hydrantSupply,
  brushWildland,
  standpipeStyleLine,
}

enum PrintableTargetArtwork {
  building,
  sedan,
  brush,
  hydrant,
  buildingAndBrush,
  sedanAndBrush,
}

enum PrintableHoseSize { inch175, inch2, inch25, inch3, ldh5 }

/// A single generated pump scenario that can be rendered on-screen and exported to PDF.
class PrintablePumpScenario {
  const PrintablePumpScenario({
    required this.id,
    required this.title,
    required this.scenarioType,
    required this.targetArtwork,
    required this.problem,
    required this.hoseSize,
    required this.hoseDiameterLabel,
    required this.lengthFt,
    required this.cValue,
    required this.nozzleLabel,
    required this.gpm,
    required this.np,
    required this.elevationFeet,
    required this.elevationPsi,
    required this.appliancePsi,
    required this.frictionLoss,
    required this.pumpPressureRaw,
    required this.pumpPressureRounded,
    required this.mathExplanation,
  });

  final String id;
  final String title;
  final PrintableScenarioType scenarioType;
  final PrintableTargetArtwork targetArtwork;
  final String problem;

  final PrintableHoseSize hoseSize;
  final String hoseDiameterLabel;
  final int lengthFt;
  final double cValue;
  final String nozzleLabel;
  final int gpm;
  final int np;

  final int elevationFeet;
  final int elevationPsi;
  final int appliancePsi;

  final int frictionLoss;
  final int pumpPressureRaw;
  final int pumpPressureRounded;

  /// Human-readable math steps. Intended to be printed in the answer key.
  final String mathExplanation;

  PrintablePumpScenario copyWith({
    String? id,
    String? title,
    PrintableScenarioType? scenarioType,
    PrintableTargetArtwork? targetArtwork,
    String? problem,
    PrintableHoseSize? hoseSize,
    String? hoseDiameterLabel,
    int? lengthFt,
    double? cValue,
    String? nozzleLabel,
    int? gpm,
    int? np,
    int? elevationFeet,
    int? elevationPsi,
    int? appliancePsi,
    int? frictionLoss,
    int? pumpPressureRaw,
    int? pumpPressureRounded,
    String? mathExplanation,
  }) {
    return PrintablePumpScenario(
      id: id ?? this.id,
      title: title ?? this.title,
      scenarioType: scenarioType ?? this.scenarioType,
      targetArtwork: targetArtwork ?? this.targetArtwork,
      problem: problem ?? this.problem,
      hoseSize: hoseSize ?? this.hoseSize,
      hoseDiameterLabel: hoseDiameterLabel ?? this.hoseDiameterLabel,
      lengthFt: lengthFt ?? this.lengthFt,
      cValue: cValue ?? this.cValue,
      nozzleLabel: nozzleLabel ?? this.nozzleLabel,
      gpm: gpm ?? this.gpm,
      np: np ?? this.np,
      elevationFeet: elevationFeet ?? this.elevationFeet,
      elevationPsi: elevationPsi ?? this.elevationPsi,
      appliancePsi: appliancePsi ?? this.appliancePsi,
      frictionLoss: frictionLoss ?? this.frictionLoss,
      pumpPressureRaw: pumpPressureRaw ?? this.pumpPressureRaw,
      pumpPressureRounded: pumpPressureRounded ?? this.pumpPressureRounded,
      mathExplanation: mathExplanation ?? this.mathExplanation,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'scenarioType': scenarioType.name,
    'targetArtwork': targetArtwork.name,
    'problem': problem,
    'hoseSize': hoseSize.name,
    'hoseDiameterLabel': hoseDiameterLabel,
    'lengthFt': lengthFt,
    'cValue': cValue,
    'nozzleLabel': nozzleLabel,
    'gpm': gpm,
    'np': np,
    'elevationFeet': elevationFeet,
    'elevationPsi': elevationPsi,
    'appliancePsi': appliancePsi,
    'frictionLoss': frictionLoss,
    'pumpPressureRaw': pumpPressureRaw,
    'pumpPressureRounded': pumpPressureRounded,
    'mathExplanation': mathExplanation,
  };

  static PrintablePumpScenario fromJson(Map<String, dynamic> json) => PrintablePumpScenario(
    id: json['id'] as String,
    title: json['title'] as String,
    scenarioType: PrintableScenarioType.values.byName(json['scenarioType'] as String),
    targetArtwork: PrintableTargetArtwork.values.byName(json['targetArtwork'] as String),
    problem: json['problem'] as String,
    hoseSize: PrintableHoseSize.values.byName(json['hoseSize'] as String),
    hoseDiameterLabel: json['hoseDiameterLabel'] as String,
    lengthFt: (json['lengthFt'] as num).toInt(),
    cValue: (json['cValue'] as num).toDouble(),
    nozzleLabel: json['nozzleLabel'] as String,
    gpm: (json['gpm'] as num).toInt(),
    np: (json['np'] as num).toInt(),
    elevationFeet: (json['elevationFeet'] as num).toInt(),
    elevationPsi: (json['elevationPsi'] as num).toInt(),
    appliancePsi: (json['appliancePsi'] as num).toInt(),
    frictionLoss: (json['frictionLoss'] as num).toInt(),
    pumpPressureRaw: (json['pumpPressureRaw'] as num).toInt(),
    pumpPressureRounded: (json['pumpPressureRounded'] as num).toInt(),
    mathExplanation: json['mathExplanation'] as String,
  );
}

class PrintableScenarioInputs {
  const PrintableScenarioInputs({
    required this.title,
    required this.scenarioType,
    required this.targetArtwork,
    required this.hoseSize,
    required this.cValue,
    required this.lengthFt,
    required this.nozzleLabel,
    required this.gpm,
    required this.np,
    required this.elevationFeet,
    required this.appliancePsi,
    required this.problem,
  });

  final String title;
  final PrintableScenarioType scenarioType;
  final PrintableTargetArtwork targetArtwork;
  final PrintableHoseSize hoseSize;
  final double cValue;
  final int lengthFt;
  final String nozzleLabel;
  final int gpm;
  final int np;
  final int elevationFeet;
  final int appliancePsi;
  final String problem;
}

class PrintableScenarioCalculator {
  const PrintableScenarioCalculator._();

  static int roundToNearest5(int value) => ((value / 5.0).round() * 5).toInt();

  static String hoseLabelForSize(PrintableHoseSize size) => switch (size) {
    PrintableHoseSize.inch175 => '1¾ inch hose',
    PrintableHoseSize.inch2 => '2 inch hose',
    PrintableHoseSize.inch25 => '2½ inch hose',
    PrintableHoseSize.inch3 => '3 inch hose',
    PrintableHoseSize.ldh5 => '5 inch LDH',
  };

  static PrintablePumpScenario buildScenario({required String id, required PrintableScenarioInputs inputs}) {
    final hoseDiameterLabel = hoseLabelForSize(inputs.hoseSize);
    final gpmRatio = inputs.gpm / 100.0;
    final lengthFactor = inputs.lengthFt / 100.0;
    final flExact = inputs.cValue * pow(gpmRatio, 2) * lengthFactor;
    final frictionLoss = flExact.round();

    final elevationPsi = (inputs.elevationFeet * 0.5).round();
    final pumpPressureRaw = inputs.np + frictionLoss + elevationPsi + inputs.appliancePsi;
    final pumpPressureRounded = roundToNearest5(pumpPressureRaw);

    final elevSign = elevationPsi == 0 ? '' : (elevationPsi > 0 ? ' + $elevationPsi' : ' - ${elevationPsi.abs()}');
    final appSign = inputs.appliancePsi == 0 ? '' : ' + ${inputs.appliancePsi}';
    final ppMath = '${inputs.np} + $frictionLoss$elevSign$appSign = $pumpPressureRaw psi → ${pumpPressureRounded} psi (nearest 5)';

    final mathExplanation = 'FL = ${_fmt(inputs.cValue)} × (${_fmt(gpmRatio)})² × ${_fmt(lengthFactor)} = ${frictionLoss} psi.\n'
        'PP = NP + FL ± Elevation + Appliance\n'
        'PP = ${inputs.np} + $frictionLoss + ($elevationPsi) + ${inputs.appliancePsi} = $pumpPressureRaw psi.\n'
        'Round to nearest 5 PSI → $pumpPressureRounded psi.\n'
        '($ppMath)';

    return PrintablePumpScenario(
      id: id,
      title: inputs.title,
      scenarioType: inputs.scenarioType,
      targetArtwork: inputs.targetArtwork,
      problem: inputs.problem,
      hoseSize: inputs.hoseSize,
      hoseDiameterLabel: hoseDiameterLabel,
      lengthFt: inputs.lengthFt,
      cValue: inputs.cValue,
      nozzleLabel: inputs.nozzleLabel,
      gpm: inputs.gpm,
      np: inputs.np,
      elevationFeet: inputs.elevationFeet,
      elevationPsi: elevationPsi,
      appliancePsi: inputs.appliancePsi,
      frictionLoss: frictionLoss,
      pumpPressureRaw: pumpPressureRaw,
      pumpPressureRounded: pumpPressureRounded,
      mathExplanation: mathExplanation,
    );
  }

  static String _fmt(num v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('00') ? v.toStringAsFixed(0) : s.endsWith('0') ? v.toStringAsFixed(1) : s;
  }
}

class PrintableScenarioGenerator {
  PrintableScenarioGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const List<int> _lengthOptions = [100, 150, 200, 250, 300];

  static const Map<PrintableHoseSize, double> defaultC = {
    PrintableHoseSize.inch175: 15.5,
    PrintableHoseSize.inch25: 2,
    PrintableHoseSize.inch2: 8,
    PrintableHoseSize.inch3: 0.8,
    PrintableHoseSize.ldh5: 0.08,
  };

  static const _nozzlesBeginnerMixed = <({String label, int gpm, int np})>[
    (label: 'Chief XD Fog — 185 GPM @ 50 PSI', gpm: 185, np: 50),
    (label: 'Fog Nozzle — 150 GPM @ 50 PSI', gpm: 150, np: 50),
  ];

  static const _nozzlesMixedExtra = <({String label, int gpm, int np})>[
    (label: 'Smooth Bore 1 1/8 — 265 GPM @ 50 PSI', gpm: 265, np: 50),
    (label: 'Fog Nozzle — 250 GPM @ 50 PSI', gpm: 250, np: 50),
  ];

  static const _nozzlesAdvancedExtra = <({String label, int gpm, int np})>[
    (label: 'Smooth Bore 15/16 — 185 GPM @ 50 PSI', gpm: 185, np: 50),
    (label: 'Smooth Bore 1 1/8 — 265 GPM @ 50 PSI', gpm: 265, np: 50),
    (label: 'Fog Nozzle — 250 GPM @ 50 PSI', gpm: 250, np: 50),
  ];

  static const _titlesByType = <PrintableScenarioType, List<String>>{
    PrintableScenarioType.attackLine: ['Attack Line Stretch', 'Front Door Stretch', 'Single Line Attack'],
    PrintableScenarioType.vehicleFire: ['Vehicle Fire Attack', 'Car Fire Line', 'Vehicle Fire Knockdown'],
    PrintableScenarioType.commercialBuilding: ['Commercial Attack Line', 'Storefront Stretch', 'Building Fire Attack'],
    PrintableScenarioType.hydrantSupply: ['Hydrant Supply / Relay', 'LDH Supply Line', 'Hydrant Lay'],
    PrintableScenarioType.brushWildland: ['Brush Line', 'Wildland Attack', 'Brush Fire Line'],
    PrintableScenarioType.standpipeStyleLine: ['Standpipe-Style Line', 'High-Rise Pack', 'Standpipe Stretch'],
  };

  T pickRandom<T>(List<T> list) => list[_random.nextInt(list.length)];

  PrintablePumpScenario generatePrintableScenario({required int index, required PrintableWorksheetDifficulty difficulty}) {
    final scenarioType = _pickScenarioType(difficulty);
    final targetArtwork = _targetForScenarioType(scenarioType, difficulty);
    final title = pickRandom(_titlesByType[scenarioType] ?? const ['Custom Pump Scenario']);

    final (hoseSize, cValue) = _pickHoseAndC(difficulty);
    final lengthFt = _pickLength(difficulty);
    final nozzle = _pickNozzle(difficulty, hoseSize);
    final elevationFeet = _pickElevationFeet(difficulty);
    final appliancePsi = _pickAppliancePsi(difficulty, scenarioType);

    final problem = _defaultProblem(scenarioType);
    return PrintableScenarioCalculator.buildScenario(
      id: 'pws_${DateTime.now().millisecondsSinceEpoch}_${index}_${_random.nextInt(1 << 20)}',
      inputs: PrintableScenarioInputs(
        title: title,
        scenarioType: scenarioType,
        targetArtwork: targetArtwork,
        hoseSize: hoseSize,
        cValue: cValue,
        lengthFt: lengthFt,
        nozzleLabel: nozzle.label,
        gpm: nozzle.gpm,
        np: nozzle.np,
        elevationFeet: elevationFeet,
        appliancePsi: appliancePsi,
        problem: problem,
      ),
    );
  }

  List<PrintablePumpScenario> generatePrintableSheet({required PrintableWorksheetDifficulty difficulty, required int scenarioCount}) {
    return List.generate(scenarioCount, (i) => generatePrintableScenario(index: i + 1, difficulty: difficulty));
  }

  PrintableScenarioType _pickScenarioType(PrintableWorksheetDifficulty difficulty) {
    if (difficulty == PrintableWorksheetDifficulty.beginner) return PrintableScenarioType.attackLine;
    if (difficulty == PrintableWorksheetDifficulty.mixedBeginnerIntermediate) {
      return pickRandom(const [PrintableScenarioType.attackLine, PrintableScenarioType.vehicleFire, PrintableScenarioType.commercialBuilding]);
    }
    // Advanced.
    return pickRandom(PrintableScenarioType.values);
  }

  PrintableTargetArtwork _targetForScenarioType(PrintableScenarioType type, PrintableWorksheetDifficulty difficulty) {
    switch (type) {
      case PrintableScenarioType.vehicleFire:
        return difficulty == PrintableWorksheetDifficulty.advanced && _random.nextInt(5) == 0 ? PrintableTargetArtwork.sedanAndBrush : PrintableTargetArtwork.sedan;
      case PrintableScenarioType.brushWildland:
        return PrintableTargetArtwork.brush;
      case PrintableScenarioType.hydrantSupply:
        return PrintableTargetArtwork.hydrant;
      case PrintableScenarioType.commercialBuilding:
        return difficulty == PrintableWorksheetDifficulty.advanced && _random.nextBool() ? PrintableTargetArtwork.buildingAndBrush : PrintableTargetArtwork.building;
      case PrintableScenarioType.attackLine:
      case PrintableScenarioType.standpipeStyleLine:
        // TODO: Add house-fire.png later for residential targets.
        return PrintableTargetArtwork.building;
    }
  }

  (PrintableHoseSize, double) _pickHoseAndC(PrintableWorksheetDifficulty difficulty) {
    if (difficulty == PrintableWorksheetDifficulty.beginner) {
      return (PrintableHoseSize.inch175, defaultC[PrintableHoseSize.inch175]!);
    }
    if (difficulty == PrintableWorksheetDifficulty.mixedBeginnerIntermediate) {
      final size = _random.nextBool() ? PrintableHoseSize.inch175 : PrintableHoseSize.inch25;
      return (size, defaultC[size]!);
    }
    // Advanced.
    final size = pickRandom(const [PrintableHoseSize.inch175, PrintableHoseSize.inch2, PrintableHoseSize.inch25, PrintableHoseSize.inch3, PrintableHoseSize.ldh5]);
    return (size, defaultC[size]!);
  }

  int _pickLength(PrintableWorksheetDifficulty difficulty) {
    if (difficulty == PrintableWorksheetDifficulty.advanced) {
      final long = pickRandom(const [300, 400, 500, 600]);
      return _random.nextBool() ? pickRandom(_lengthOptions) : long;
    }
    return pickRandom(_lengthOptions);
  }

  ({String label, int gpm, int np}) _pickNozzle(PrintableWorksheetDifficulty difficulty, PrintableHoseSize hoseSize) {
    if (difficulty == PrintableWorksheetDifficulty.beginner) return pickRandom(_nozzlesBeginnerMixed);
    if (difficulty == PrintableWorksheetDifficulty.mixedBeginnerIntermediate) {
      final all = [..._nozzlesBeginnerMixed, ..._nozzlesMixedExtra];
      return pickRandom(all);
    }
    // Advanced.
    final all = [..._nozzlesBeginnerMixed, ..._nozzlesMixedExtra, ..._nozzlesAdvancedExtra];
    return pickRandom(all);
  }

  int _pickElevationFeet(PrintableWorksheetDifficulty difficulty) {
    if (difficulty == PrintableWorksheetDifficulty.beginner) return pickRandom(const [0, 0, 0, 10, -10]);
    if (difficulty == PrintableWorksheetDifficulty.mixedBeginnerIntermediate) return pickRandom(const [0, 10, -10, 20, -20, 30]);
    return pickRandom(const [0, 10, -10, 20, -20, 30, 40, -40, 60, -60]);
  }

  int _pickAppliancePsi(PrintableWorksheetDifficulty difficulty, PrintableScenarioType type) {
    if (difficulty == PrintableWorksheetDifficulty.beginner) return pickRandom(const [0, 0, 0, 10]);
    if (difficulty == PrintableWorksheetDifficulty.mixedBeginnerIntermediate) return pickRandom(const [0, 0, 10, 10, 15]);
    // Advanced.
    if (type == PrintableScenarioType.standpipeStyleLine) return pickRandom(const [25, 50, 65]);
    return pickRandom(const [0, 10, 15, 25, 35]);
  }

  String _defaultProblem(PrintableScenarioType type) {
    return switch (type) {
      PrintableScenarioType.attackLine => 'Engine 181 is stretching one attack line to a fire. Calculate the pump discharge pressure.',
      PrintableScenarioType.vehicleFire => 'Engine 181 is stretching one attack line to a vehicle fire. Calculate the pump discharge pressure.',
      PrintableScenarioType.commercialBuilding => 'Engine 181 is stretching one attack line to a commercial building fire. Calculate the pump discharge pressure.',
      PrintableScenarioType.hydrantSupply => 'Engine 181 is laying a supply line from a hydrant. Calculate the pump discharge pressure.',
      PrintableScenarioType.brushWildland => 'Engine 181 is stretching one line for a brush fire. Calculate the pump discharge pressure.',
      PrintableScenarioType.standpipeStyleLine => 'Engine 181 is supplying a standpipe-style line. Calculate the pump discharge pressure.',
    };
  }
}
