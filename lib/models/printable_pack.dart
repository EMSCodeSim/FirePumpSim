import 'dart:math';

import 'package:firepumpsim/models/printable_pump_scenario.dart';

/// A purchasable/unlockable pack of branded printable training pages.
///
/// This is intentionally local/offline-only. Purchase/unlock state is stored
/// via SharedPreferences in [PrintablePackStorage].
class PrintablePack {
  const PrintablePack({
    required this.packId,
    required this.title,
    required this.description,
    required this.isFree,
    required this.pageCount,
    required this.buildPages,
  });

  final String packId;
  final String title;
  final String description;
  final bool isFree;

  /// Intended number of printable pages in the pack.
  ///
  /// This is for UI display and for consistent “10-page starter pack” behavior.
  final int pageCount;

  /// Builds the printable pages for this pack.
  ///
  /// Each page is represented as a [PrintablePumpScenario] so we can reuse the
  /// existing scene + hydraulic calculations and provide a consistent answer key.
  final List<PrintablePumpScenario> Function() buildPages;
}

class PrintablePacksCatalog {
  const PrintablePacksCatalog._();

  static const String starterPackId = 'printable_starter_pack';

  static List<PrintablePack> allPacks() {
    return [
      PrintablePack(
        packId: starterPackId,
        title: 'FirePumpSim Printable Starter Pack',
        description: '10 branded, ready-to-print hydraulic worksheets. Included with the free app.',
        isFree: true,
        pageCount: 10,
        buildPages: PrintablePackScenarioFactory.starterPackPages,
      ),
      PrintablePack(
        packId: 'printable_driver_operator_1',
        title: 'Driver/Operator I Pack',
        description: 'Core PDP problems with common attack line and supply evolutions.',
        isFree: false,
        pageCount: 10,
        buildPages: () => PrintablePackScenarioFactory.seededPages(seed: 101, focus: PrintablePackFocus.driverOperator1),
      ),
      PrintablePack(
        packId: 'printable_driver_operator_2',
        title: 'Driver/Operator II Pack',
        description: 'More complex hydraulics: longer lays, larger flows, and mixed components.',
        isFree: false,
        pageCount: 10,
        buildPages: () => PrintablePackScenarioFactory.seededPages(seed: 202, focus: PrintablePackFocus.driverOperator2),
      ),
      PrintablePack(
        packId: 'printable_standpipe',
        title: 'Standpipe Pack',
        description: 'Standpipe-style friction loss and appliance/elevation practice.',
        isFree: false,
        pageCount: 10,
        buildPages: () => PrintablePackScenarioFactory.seededPages(seed: 303, focus: PrintablePackFocus.standpipe),
      ),
      PrintablePack(
        packId: 'printable_water_supply',
        title: 'Water Supply Pack',
        description: 'Hydrant supply, LDH, and water supply decision practice.',
        isFree: false,
        pageCount: 10,
        buildPages: () => PrintablePackScenarioFactory.seededPages(seed: 404, focus: PrintablePackFocus.waterSupply),
      ),
      PrintablePack(
        packId: 'printable_relay_pumping',
        title: 'Relay Pumping Pack',
        description: 'Relay-style pressure problems and longer distance operations.',
        isFree: false,
        pageCount: 10,
        buildPages: () => PrintablePackScenarioFactory.seededPages(seed: 505, focus: PrintablePackFocus.relayPumping),
      ),
      PrintablePack(
        packId: 'printable_master_stream',
        title: 'Master Stream Pack',
        description: 'High-flow problems with clean hose layouts and readable givens.',
        isFree: false,
        pageCount: 10,
        buildPages: () => PrintablePackScenarioFactory.seededPages(seed: 606, focus: PrintablePackFocus.masterStream),
      ),
      PrintablePack(
        packId: 'printable_wildland_rural',
        title: 'Wildland / Rural Water Pack',
        description: 'Rural operations style problems: longer lines and varying elevations.',
        isFree: false,
        pageCount: 10,
        buildPages: () => PrintablePackScenarioFactory.seededPages(seed: 707, focus: PrintablePackFocus.wildlandRural),
      ),
    ];
  }
}

enum PrintablePackFocus {
  driverOperator1,
  driverOperator2,
  standpipe,
  waterSupply,
  relayPumping,
  masterStream,
  wildlandRural,
}

/// Deterministic scenario pages for printable packs.
///
/// “Deterministic” means the same pack always yields the same 10 pages so the
/// free pack feels like real content and instructors can reference page numbers.
class PrintablePackScenarioFactory {
  const PrintablePackScenarioFactory._();

  static List<PrintablePumpScenario> starterPackPages() {
    // Hand-curated starter pages.
    // Keep values realistic and varied without relying on runtime randomness.
    return [
      _s(
        id: 'starter_01',
        title: 'Front Door Attack Line',
        type: PrintableScenarioType.attackLine,
        artwork: PrintableTargetArtwork.building,
        hose: PrintableHoseSize.inch175,
        c: 15.5,
        len: 200,
        nozzle: 'Fog Nozzle — 150 GPM @ 50 PSI',
        gpm: 150,
        np: 50,
        elevFt: 0,
        appPsi: 0,
        problem: 'Engine 181 is stretching one 1¾" attack line to the front door. Calculate the pump discharge pressure.',
      ),
      _s(
        id: 'starter_02',
        title: 'Vehicle Fire Line',
        type: PrintableScenarioType.vehicleFire,
        artwork: PrintableTargetArtwork.sedan,
        hose: PrintableHoseSize.inch175,
        c: 15.5,
        len: 150,
        nozzle: 'Chief XD Fog — 185 GPM @ 50 PSI',
        gpm: 185,
        np: 50,
        elevFt: -10,
        appPsi: 0,
        problem: 'Engine 181 is stretching one 1¾" line to a vehicle fire. Calculate the pump discharge pressure.',
      ),
      _s(
        id: 'starter_03',
        title: 'Commercial Stretch',
        type: PrintableScenarioType.commercialBuilding,
        artwork: PrintableTargetArtwork.building,
        hose: PrintableHoseSize.inch25,
        c: 2,
        len: 250,
        nozzle: 'Fog Nozzle — 250 GPM @ 50 PSI',
        gpm: 250,
        np: 50,
        elevFt: 10,
        appPsi: 10,
        problem: 'Engine 181 is stretching one 2½" line to a commercial occupancy. Calculate the pump discharge pressure.',
      ),
      _s(
        id: 'starter_04',
        title: 'Hydrant Supply (LDH)',
        type: PrintableScenarioType.hydrantSupply,
        artwork: PrintableTargetArtwork.hydrant,
        hose: PrintableHoseSize.ldh5,
        c: 0.08,
        len: 300,
        nozzle: 'Supply to Engine — 1000 GPM @ 0 PSI',
        gpm: 1000,
        np: 0,
        elevFt: 0,
        appPsi: 0,
        problem: 'Engine 181 is supplied by 5" LDH from a hydrant. Calculate the friction loss and pump pressure needed to flow 1000 GPM.',
      ),
      _s(
        id: 'starter_05',
        title: 'Brush Line',
        type: PrintableScenarioType.brushWildland,
        artwork: PrintableTargetArtwork.brush,
        hose: PrintableHoseSize.inch175,
        c: 15.5,
        len: 300,
        nozzle: 'Fog Nozzle — 150 GPM @ 50 PSI',
        gpm: 150,
        np: 50,
        elevFt: 20,
        appPsi: 0,
        problem: 'Engine 181 is stretching one 1¾" line to a brush fire. Calculate the pump discharge pressure.',
      ),
      _s(
        id: 'starter_06',
        title: 'Standpipe-Style Line (Appliance)',
        type: PrintableScenarioType.standpipeStyleLine,
        artwork: PrintableTargetArtwork.building,
        hose: PrintableHoseSize.inch175,
        c: 15.5,
        len: 200,
        nozzle: 'Smooth Bore 15/16 — 185 GPM @ 50 PSI',
        gpm: 185,
        np: 50,
        elevFt: 40,
        appPsi: 25,
        problem: 'Engine 181 is supplying a standpipe-style line to an upper floor. Calculate the pump discharge pressure.',
      ),
      _s(
        id: 'starter_07',
        title: '2" Attack Line',
        type: PrintableScenarioType.attackLine,
        artwork: PrintableTargetArtwork.building,
        hose: PrintableHoseSize.inch2,
        c: 8,
        len: 250,
        nozzle: 'Fog Nozzle — 250 GPM @ 50 PSI',
        gpm: 250,
        np: 50,
        elevFt: 0,
        appPsi: 0,
        problem: 'Engine 181 is stretching one 2" line for a larger flow requirement. Calculate the pump discharge pressure.',
      ),
      _s(
        id: 'starter_08',
        title: '3" Supply to Wye',
        type: PrintableScenarioType.hydrantSupply,
        artwork: PrintableTargetArtwork.hydrant,
        hose: PrintableHoseSize.inch3,
        c: 0.8,
        len: 400,
        nozzle: 'Supply to Wye — 500 GPM @ 0 PSI',
        gpm: 500,
        np: 0,
        elevFt: -20,
        appPsi: 0,
        problem: 'Engine 181 is pumping through 3" supply line to a wye. Calculate the pump pressure to flow 500 GPM.',
      ),
      _s(
        id: 'starter_09',
        title: 'Vehicle + Brush Edge',
        type: PrintableScenarioType.vehicleFire,
        artwork: PrintableTargetArtwork.sedanAndBrush,
        hose: PrintableHoseSize.inch175,
        c: 15.5,
        len: 250,
        nozzle: 'Chief XD Fog — 185 GPM @ 50 PSI',
        gpm: 185,
        np: 50,
        elevFt: 10,
        appPsi: 10,
        problem: 'Engine 181 is stretching one 1¾" line to a vehicle fire at the brush line. Calculate the pump discharge pressure.',
      ),
      _s(
        id: 'starter_10',
        title: 'Commercial + Brush Exposure',
        type: PrintableScenarioType.commercialBuilding,
        artwork: PrintableTargetArtwork.buildingAndBrush,
        hose: PrintableHoseSize.inch25,
        c: 2,
        len: 300,
        nozzle: 'Smooth Bore 1 1/8 — 265 GPM @ 50 PSI',
        gpm: 265,
        np: 50,
        elevFt: 30,
        appPsi: 15,
        problem: 'Engine 181 is stretching one 2½" line for exposure protection. Calculate the pump discharge pressure.',
      ),
    ];
  }

  static List<PrintablePumpScenario> seededPages({required int seed, required PrintablePackFocus focus}) {
    // Keep content usable even before we add more artwork assets.
    // We vary scenario type/artwork/hose/gpm with a deterministic random.
    final r = Random(seed);

    PrintableScenarioType pickType() {
      return switch (focus) {
        PrintablePackFocus.standpipe => PrintableScenarioType.standpipeStyleLine,
        PrintablePackFocus.waterSupply => PrintableScenarioType.hydrantSupply,
        PrintablePackFocus.relayPumping => PrintableScenarioType.hydrantSupply,
        PrintablePackFocus.masterStream => PrintableScenarioType.commercialBuilding,
        PrintablePackFocus.wildlandRural => PrintableScenarioType.brushWildland,
        PrintablePackFocus.driverOperator1 => r.nextBool() ? PrintableScenarioType.attackLine : PrintableScenarioType.vehicleFire,
        PrintablePackFocus.driverOperator2 => PrintableScenarioType.values[r.nextInt(PrintableScenarioType.values.length)],
      };
    }

    PrintableTargetArtwork pickArtwork(PrintableScenarioType type) {
      return switch (type) {
        PrintableScenarioType.vehicleFire => r.nextInt(4) == 0 ? PrintableTargetArtwork.sedanAndBrush : PrintableTargetArtwork.sedan,
        PrintableScenarioType.brushWildland => PrintableTargetArtwork.brush,
        PrintableScenarioType.hydrantSupply => PrintableTargetArtwork.hydrant,
        PrintableScenarioType.commercialBuilding => r.nextInt(4) == 0 ? PrintableTargetArtwork.buildingAndBrush : PrintableTargetArtwork.building,
        PrintableScenarioType.attackLine => PrintableTargetArtwork.building,
        PrintableScenarioType.standpipeStyleLine => PrintableTargetArtwork.building,
      };
    }

    (PrintableHoseSize, double) pickHose(PrintableScenarioType type) {
      if (type == PrintableScenarioType.hydrantSupply) {
        final size = r.nextBool() ? PrintableHoseSize.ldh5 : PrintableHoseSize.inch3;
        return (size, PrintableScenarioGenerator.defaultC[size]!);
      }
      if (type == PrintableScenarioType.commercialBuilding) {
        final size = r.nextBool() ? PrintableHoseSize.inch25 : PrintableHoseSize.inch2;
        return (size, PrintableScenarioGenerator.defaultC[size]!);
      }
      return (PrintableHoseSize.inch175, PrintableScenarioGenerator.defaultC[PrintableHoseSize.inch175]!);
    }

    int pickGpm(PrintableScenarioType type, PrintableHoseSize hose) {
      if (hose == PrintableHoseSize.ldh5) return [750, 900, 1000][r.nextInt(3)];
      if (type == PrintableScenarioType.standpipeStyleLine) return [150, 185, 200][r.nextInt(3)];
      if (hose == PrintableHoseSize.inch25 || hose == PrintableHoseSize.inch2) return [200, 250, 265][r.nextInt(3)];
      return [150, 185][r.nextInt(2)];
    }

    int pickNp(PrintableScenarioType type, PrintableHoseSize hose) {
      if (hose == PrintableHoseSize.ldh5) return 0;
      return 50;
    }

    int pickElevationFt() {
      return switch (focus) {
        PrintablePackFocus.wildlandRural => [-40, -20, 0, 20, 40, 60][r.nextInt(6)],
        _ => [-20, -10, 0, 10, 20, 30, 40][r.nextInt(7)],
      };
    }

    int pickAppliancePsi(PrintableScenarioType type) {
      if (type == PrintableScenarioType.standpipeStyleLine) return [25, 50, 65][r.nextInt(3)];
      return [0, 0, 10, 15][r.nextInt(4)];
    }

    int pickLengthFt(PrintableScenarioType type) {
      if (focus == PrintablePackFocus.relayPumping) return [500, 600, 800, 1000][r.nextInt(4)];
      if (focus == PrintablePackFocus.waterSupply) return [300, 400, 500][r.nextInt(3)];
      return [150, 200, 250, 300][r.nextInt(4)];
    }

    String titleFor(PrintableScenarioType type) {
      return switch (type) {
        PrintableScenarioType.attackLine => 'Attack Line Stretch',
        PrintableScenarioType.vehicleFire => 'Vehicle Fire Attack',
        PrintableScenarioType.commercialBuilding => 'Commercial Attack',
        PrintableScenarioType.hydrantSupply => 'Water Supply Evolution',
        PrintableScenarioType.brushWildland => 'Wildland Line',
        PrintableScenarioType.standpipeStyleLine => 'Standpipe-Style Line',
      };
    }

    String problemFor(PrintableScenarioType type, PrintableHoseSize hose) {
      final hoseLabel = switch (hose) {
        PrintableHoseSize.inch175 => '1¾"',
        PrintableHoseSize.inch2 => '2"',
        PrintableHoseSize.inch25 => '2½"',
        PrintableHoseSize.inch3 => '3"',
        PrintableHoseSize.ldh5 => '5"',
      };
      return switch (type) {
        PrintableScenarioType.hydrantSupply => 'Engine 181 is pumping a $hoseLabel supply line. Calculate the pump discharge pressure.',
        PrintableScenarioType.standpipeStyleLine => 'Engine 181 is supplying a standpipe-style line. Calculate the pump discharge pressure.',
        PrintableScenarioType.brushWildland => 'Engine 181 is stretching a $hoseLabel line to a brush fire. Calculate the pump discharge pressure.',
        PrintableScenarioType.vehicleFire => 'Engine 181 is stretching a $hoseLabel line to a vehicle fire. Calculate the pump discharge pressure.',
        PrintableScenarioType.commercialBuilding => 'Engine 181 is stretching a $hoseLabel line to a commercial fire. Calculate the pump discharge pressure.',
        PrintableScenarioType.attackLine => 'Engine 181 is stretching a $hoseLabel attack line. Calculate the pump discharge pressure.',
      };
    }

    final pages = <PrintablePumpScenario>[];
    for (var i = 0; i < 10; i++) {
      final type = pickType();
      final artwork = pickArtwork(type);
      final (hose, cVal) = pickHose(type);
      final gpm = pickGpm(type, hose);
      final np = pickNp(type, hose);
      final elevFt = pickElevationFt();
      final appPsi = pickAppliancePsi(type);
      final len = pickLengthFt(type);
      final nozzleLabel = np == 0 ? 'Supply Flow — $gpm GPM @ 0 PSI' : 'Nozzle — $gpm GPM @ $np PSI';

      pages.add(
        _s(
          id: '${focus.name}_${i + 1}',
          title: '${titleFor(type)} ${i + 1}',
          type: type,
          artwork: artwork,
          hose: hose,
          c: cVal,
          len: len,
          nozzle: nozzleLabel,
          gpm: gpm,
          np: np,
          elevFt: elevFt,
          appPsi: appPsi,
          problem: problemFor(type, hose),
        ),
      );
    }
    return pages;
  }

  static PrintablePumpScenario _s({
    required String id,
    required String title,
    required PrintableScenarioType type,
    required PrintableTargetArtwork artwork,
    required PrintableHoseSize hose,
    required double c,
    required int len,
    required String nozzle,
    required int gpm,
    required int np,
    required int elevFt,
    required int appPsi,
    required String problem,
  }) {
    return PrintableScenarioCalculator.buildScenario(
      id: id,
      inputs: PrintableScenarioInputs(
        title: title,
        scenarioType: type,
        targetArtwork: artwork,
        hoseSize: hose,
        cValue: c,
        lengthFt: len,
        nozzleLabel: nozzle,
        gpm: gpm,
        np: np,
        elevationFeet: elevFt,
        appliancePsi: appPsi,
        problem: problem,
      ),
    );
  }
}
