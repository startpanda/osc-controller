import 'osc_models.dart';

/// ADM-OSC v1.0 preset controls.
/// See: https://immersive-audio-live.github.io/ADM-OSC/
abstract final class AdmOsc {
  static const defaultSendPort = 4001;
  static const defaultReturnPort = 4002;

  static String objectAddress(int objectNumber, String suffix) =>
      '/adm/obj/$objectNumber/$suffix';

  static const envChange = '/adm/env/change';
  static const lisXyz = '/adm/lis/xyz';
  static const lisYpr = '/adm/lis/ypr';
}

abstract final class AdmOscPresets {
  static List<OscControl> buildControls(int objectChannel) {
    final id = DateTime.now().millisecondsSinceEpoch;
    var index = 0;
    String nextId() => 'adm_${id}_${index++}';

    OscControl objectControl({
      required String suffix,
      required String label,
      required ControlType type,
      required OscDataType dataType,
      required List<OscArgument> args,
      dynamic value,
      double min = 0,
      double max = 1,
      double step = 0.01,
      bool isQuery = false,
      dynamic toggleOnValue,
      dynamic toggleOffValue,
    }) {
      return OscControl(
        id: nextId(),
        type: type,
        label: label,
        address: AdmOsc.objectAddress(objectChannel, suffix),
        dataType: dataType,
        args: args,
        value: value,
        min: min,
        max: max,
        step: step,
        isAdmOsc: true,
        admUsesObjectChannel: true,
        admObjectSuffix: suffix,
        admIsQuery: isQuery,
        toggleOnValue: toggleOnValue,
        toggleOffValue: toggleOffValue,
      );
    }

    OscControl fixedControl({
      required String address,
      required String label,
      required ControlType type,
      required OscDataType dataType,
      required List<OscArgument> args,
      dynamic value,
      double min = 0,
      double max = 1,
      double step = 0.01,
      bool isQuery = false,
    }) {
      return OscControl(
        id: nextId(),
        type: type,
        label: label,
        address: address,
        dataType: dataType,
        args: args,
        value: value,
        min: min,
        max: max,
        step: step,
        isAdmOsc: true,
        admIsQuery: isQuery,
      );
    }

    const xyzValue = {'x': 0.0, 'y': 0.0, 'z': 0.0};
    const lisXyzValue = {'x': 0.0, 'y': 0.0, 'z': 0.0};

    return [
      // Object messages — /adm/obj/n/...
      objectControl(
        suffix: 'xyz',
        label: 'Position XYZ',
        type: ControlType.admXyz,
        dataType: OscDataType.f,
        value: xyzValue,
        min: -1,
        max: 1,
        args: const [
          OscArgument(type: OscDataType.f, value: 0.0),
          OscArgument(type: OscDataType.f, value: 0.0),
          OscArgument(type: OscDataType.f, value: 0.0),
        ],
      ),
      objectControl(
        suffix: 'x',
        label: 'X',
        type: ControlType.slider,
        dataType: OscDataType.f,
        value: 0.0,
        min: -1,
        max: 1,
        step: 0.01,
        args: const [OscArgument(type: OscDataType.f, value: 0.0)],
      ),
      objectControl(
        suffix: 'y',
        label: 'Y',
        type: ControlType.slider,
        dataType: OscDataType.f,
        value: 0.0,
        min: -1,
        max: 1,
        step: 0.01,
        args: const [OscArgument(type: OscDataType.f, value: 0.0)],
      ),
      objectControl(
        suffix: 'z',
        label: 'Z',
        type: ControlType.slider,
        dataType: OscDataType.f,
        value: 0.0,
        min: -1,
        max: 1,
        step: 0.01,
        args: const [OscArgument(type: OscDataType.f, value: 0.0)],
      ),
      objectControl(
        suffix: 'aed',
        label: 'Position AED',
        type: ControlType.admAed,
        dataType: OscDataType.f,
        value: const {'azim': 0.0, 'elev': 0.0, 'dist': 1.0},
        args: const [
          OscArgument(type: OscDataType.f, value: 0.0),
          OscArgument(type: OscDataType.f, value: 0.0),
          OscArgument(type: OscDataType.f, value: 1.0),
        ],
      ),
      objectControl(
        suffix: 'gain',
        label: 'Gain',
        type: ControlType.slider,
        dataType: OscDataType.f,
        value: 1.0,
        min: 0,
        max: 2,
        step: 0.01,
        args: const [OscArgument(type: OscDataType.f, value: 1.0)],
      ),
      objectControl(
        suffix: 'mute',
        label: 'Mute',
        type: ControlType.toggle,
        dataType: OscDataType.i,
        value: 0,
        toggleOffValue: 0,
        toggleOnValue: 1,
        args: const [OscArgument(type: OscDataType.i, value: 0)],
      ),
      objectControl(
        suffix: 'azim',
        label: 'Azimuth',
        type: ControlType.slider,
        dataType: OscDataType.f,
        value: 0.0,
        min: -180,
        max: 180,
        step: 0.1,
        args: const [OscArgument(type: OscDataType.f, value: 0.0)],
      ),
      objectControl(
        suffix: 'elev',
        label: 'Elevation',
        type: ControlType.slider,
        dataType: OscDataType.f,
        value: 0.0,
        min: -90,
        max: 90,
        step: 0.1,
        args: const [OscArgument(type: OscDataType.f, value: 0.0)],
      ),
      objectControl(
        suffix: 'dist',
        label: 'Distance',
        type: ControlType.slider,
        dataType: OscDataType.f,
        value: 1.0,
        min: 0,
        max: 1,
        step: 0.01,
        args: const [OscArgument(type: OscDataType.f, value: 1.0)],
      ),
      objectControl(
        suffix: 'w',
        label: 'Width',
        type: ControlType.slider,
        dataType: OscDataType.f,
        value: 0.0,
        min: 0,
        max: 1,
        step: 0.01,
        args: const [OscArgument(type: OscDataType.f, value: 0.0)],
      ),
      objectControl(
        suffix: 'dref',
        label: 'Ref Distance',
        type: ControlType.slider,
        dataType: OscDataType.f,
        value: 1.0,
        min: 0,
        max: 1,
        step: 0.01,
        args: const [OscArgument(type: OscDataType.f, value: 1.0)],
      ),
      objectControl(
        suffix: 'dmax',
        label: 'Max Distance (m)',
        type: ControlType.slider,
        dataType: OscDataType.f,
        value: 10.0,
        min: 0,
        max: 100,
        step: 0.1,
        args: const [OscArgument(type: OscDataType.f, value: 10.0)],
      ),
      objectControl(
        suffix: 'name',
        label: 'Object Name',
        type: ControlType.input,
        dataType: OscDataType.s,
        value: '',
        args: const [OscArgument(type: OscDataType.s, value: '')],
      ),
      // Query messages — send address without arguments (§2.5)
      objectControl(
        suffix: 'xyz',
        label: 'Query XYZ',
        type: ControlType.button,
        dataType: OscDataType.f,
        value: null,
        args: const [],
        isQuery: true,
      ),
      objectControl(
        suffix: 'aed',
        label: 'Query AED',
        type: ControlType.button,
        dataType: OscDataType.f,
        value: null,
        args: const [],
        isQuery: true,
      ),
      objectControl(
        suffix: 'gain',
        label: 'Query Gain',
        type: ControlType.button,
        dataType: OscDataType.f,
        value: null,
        args: const [],
        isQuery: true,
      ),
      objectControl(
        suffix: 'mute',
        label: 'Query Mute',
        type: ControlType.button,
        dataType: OscDataType.i,
        value: null,
        args: const [],
        isQuery: true,
      ),
      // Listener messages — fixed addresses (no object channel)
      fixedControl(
        address: AdmOsc.lisXyz,
        label: 'Listener XYZ',
        type: ControlType.admXyz,
        dataType: OscDataType.f,
        value: lisXyzValue,
        min: -1,
        max: 1,
        args: const [
          OscArgument(type: OscDataType.f, value: 0.0),
          OscArgument(type: OscDataType.f, value: 0.0),
          OscArgument(type: OscDataType.f, value: 0.0),
        ],
      ),
      fixedControl(
        address: AdmOsc.lisYpr,
        label: 'Listener YPR',
        type: ControlType.admYpr,
        dataType: OscDataType.f,
        value: const {'yaw': 0.0, 'pitch': 0.0, 'roll': 0.0},
        min: -180,
        max: 180,
        step: 0.1,
        args: const [
          OscArgument(type: OscDataType.f, value: 0.0),
          OscArgument(type: OscDataType.f, value: 0.0),
          OscArgument(type: OscDataType.f, value: 0.0),
        ],
      ),
      fixedControl(
        address: AdmOsc.lisYpr,
        label: 'Query Listener YPR',
        type: ControlType.button,
        dataType: OscDataType.f,
        value: null,
        args: const [],
        isQuery: true,
      ),
      // Environment message
      fixedControl(
        address: AdmOsc.envChange,
        label: 'Scene Change',
        type: ControlType.input,
        dataType: OscDataType.s,
        value: '',
        args: const [OscArgument(type: OscDataType.s, value: '')],
      ),
    ];
  }

  /// Stable identity for matching preset controls when re-adding deleted ones.
  static String presetKey(OscControl control) {
    if (!control.isAdmOsc) return control.id;
    if (control.admUsesObjectChannel && control.admObjectSuffix != null) {
      return 'obj:${control.admObjectSuffix}:${control.admIsQuery}:${control.type.name}';
    }
    return 'fixed:${control.address}:${control.admIsQuery}:${control.type.name}';
  }

  /// Fills in any missing ADM OSC preset controls, preserving existing values.
  static List<OscControl> completeMissing(
    List<OscControl> existing,
    int objectChannel,
  ) {
    final presets = buildControls(objectChannel);
    final existingByKey = {
      for (final c in existing.where((c) => c.isAdmOsc)) presetKey(c): c,
    };

    final hasMissing =
        presets.any((p) => !existingByKey.containsKey(presetKey(p)));
    if (!hasMissing) return existing;

    final completeAdm = [
      for (final preset in presets)
        existingByKey[presetKey(preset)] ?? preset,
    ];
    final nonAdm = existing.where((c) => !c.isAdmOsc).toList();
    return [...nonAdm, ...completeAdm];
  }

  static OscControl withObjectChannel(OscControl control, int objectChannel) {
    if (!control.isAdmOsc ||
        !control.admUsesObjectChannel ||
        control.admObjectSuffix == null) {
      return control;
    }
    return control.copyWith(
      address: AdmOsc.objectAddress(objectChannel, control.admObjectSuffix!),
    );
  }
}
