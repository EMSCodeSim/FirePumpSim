import 'dart:math';

/// Difficulty options for printable worksheets.
enum PrintableWorksheetDifficulty { beginner, mixedBeginnerIntermediate }

/// A single generated pump scenario that can be rendered on-screen and exported to PDF.
class PrintablePumpScenario {
  const PrintablePumpScenario({
    required this.id,
    required this.title,
    required this.targetType,
    required this.problem,
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
  final String targetType;
  final String problem;

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'targetType': targetType,
    'problem': problem,
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
    targetType: json['targetType'] as String,
    problem: json['problem'] as String,
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

class PrintableScenarioGenerator {
  PrintableScenarioGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const List<int> _lengthOptions = [150, 200, 250, 300];

  static const double c175 = 15.5;
  static const double c25 = 2;

  static const int npDefault = 50;

  static const _nozzles175 = <({String label, int gpm, int np})>[
    (label: 'Chief XD Fog', gpm: 185, np: 50),
    (label: 'Fog Nozzle', gpm: 150, np: 50),
  ];

  static const _nozzles25 = <({String label, int gpm, int np})>[
    (label: 'Smooth Bore 1 1/8', gpm: 265, np: 50),
    (label: 'Fog Nozzle', gpm: 250, np: 50),
  ];

  static const List<String> _targetTypes = ['House / residential fire', 'Building / commercial fire'];
  static const List<String> _resTitles = ['Residential Attack Line', 'Front Door Stretch', 'Garage Fire Stretch', 'Single Line House Fire'];
  static const List<String> _comTitles = ['Commercial Attack Line', 'Storefront Stretch', 'Apartment Line', 'Building Fire Attack'];

  T pickRandom<T>(List<T> list) => list[_random.nextInt(list.length)];

  int roundToNearest5(int value) => ((value / 5.0).round() * 5).toInt();

  String elevationText(int feet) {
    if (feet == 0) return '0 ft';
    if (feet > 0) return '+$feet ft';
    return '$feet ft';
  }

  String applianceText(int psi) => psi == 0 ? '0 PSI' : '${psi} PSI';

  PrintablePumpScenario generatePrintableScenario({required int index, required PrintableWorksheetDifficulty difficulty}) {
    final bool isBeginner = difficulty == PrintableWorksheetDifficulty.beginner;
    final use175 = isBeginner ? true : _random.nextBool();

    final hoseDiameterLabel = use175 ? '1¾ inch hose' : '2½ inch hose';
    final c = use175 ? c175 : c25;
    final nozzle = use175 ? pickRandom(_nozzles175) : pickRandom(_nozzles25);
    final lengthFt = pickRandom(_lengthOptions);

    final elevationFeetOptions = isBeginner ? <int>[0, 0, 0, 10, -10] : <int>[0, 10, -10, 20, -20, 30];
    final applianceOptions = isBeginner ? <int>[0, 0, 0, 10] : <int>[0, 0, 10, 10, 15];
    final elevationFeet = pickRandom(elevationFeetOptions);
    final elevationPsi = (elevationFeet * 0.5).round();
    final appliancePsi = pickRandom(applianceOptions);

    final targetType = pickRandom(_targetTypes);
    final isResidential = targetType.startsWith('House');
    final scenarioTitle = isResidential ? pickRandom(_resTitles) : pickRandom(_comTitles);
    final problem = isResidential
        ? 'Engine 181 is stretching one attack line to a residential fire. Calculate the pump discharge pressure.'
        : 'Engine 181 is stretching one attack line to a commercial building fire. Calculate the pump discharge pressure.';

    final gpmRatio = nozzle.gpm / 100.0;
    final lengthFactor = lengthFt / 100.0;
    final flExact = c * pow(gpmRatio, 2) * lengthFactor;
    final frictionLoss = flExact.round();

    final pumpPressureRaw = nozzle.np + frictionLoss + elevationPsi + appliancePsi;
    final pumpPressureRounded = roundToNearest5(pumpPressureRaw);

    final elevSign = elevationPsi == 0 ? '' : (elevationPsi > 0 ? ' + $elevationPsi' : ' - ${elevationPsi.abs()}');
    final appSign = appliancePsi == 0 ? '' : ' + $appliancePsi';
    final ppMath = '${nozzle.np} + $frictionLoss$elevSign$appSign = $pumpPressureRaw psi → ${pumpPressureRounded} psi (nearest 5)';

    final mathExplanation = 'FL = ${_fmt(c)} × (${_fmt(gpmRatio)})² × ${_fmt(lengthFactor)} = ${frictionLoss} psi.\n'
        'PP = NP + FL ± Elevation + Appliance\n'
        'PP = ${nozzle.np} + $frictionLoss + (${elevationPsi}) + $appliancePsi = $pumpPressureRaw psi.\n'
        'Round to nearest 5 PSI → $pumpPressureRounded psi.\n'
        '(${ppMath})';

    return PrintablePumpScenario(
      id: 'pws_${DateTime.now().millisecondsSinceEpoch}_${index}_${_random.nextInt(1 << 20)}',
      title: scenarioTitle,
      targetType: targetType,
      problem: problem,
      hoseDiameterLabel: hoseDiameterLabel,
      lengthFt: lengthFt,
      cValue: c,
      nozzleLabel: '${nozzle.label}, ${nozzle.gpm} GPM @ ${nozzle.np} PSI',
      gpm: nozzle.gpm,
      np: nozzle.np,
      elevationFeet: elevationFeet,
      elevationPsi: elevationPsi,
      appliancePsi: appliancePsi,
      frictionLoss: frictionLoss,
      pumpPressureRaw: pumpPressureRaw,
      pumpPressureRounded: pumpPressureRounded,
      mathExplanation: mathExplanation,
    );
  }

  List<PrintablePumpScenario> generatePrintableSheet(PrintableWorksheetDifficulty difficulty) {
    return List.generate(4, (i) => generatePrintableScenario(index: i + 1, difficulty: difficulty));
  }

  String _fmt(num v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('00') ? v.toStringAsFixed(0) : s.endsWith('0') ? v.toStringAsFixed(1) : s;
  }
}
