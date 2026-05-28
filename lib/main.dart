import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

void main() {
  runApp(const HandProjectApp());
}

class HandProjectApp extends StatelessWidget {
  const HandProjectApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF0A1014);
    const surface = Color(0xFF121A21);
    const surfaceHigh = Color(0xFF1A232C);
    const mint = Color(0xFF8FE6C4);
    const coral = Color(0xFFFF8A7A);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hand Project',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: mint,
          secondary: coral,
          surface: surface,
          surfaceContainerHighest: surfaceHigh,
          error: coral,
        ),
        fontFamily: 'Roboto',
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            foregroundColor: const Color(0xFF07110E),
            backgroundColor: mint,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE9F4F1),
            side: const BorderSide(color: Color(0xFF2B3742)),
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const ControlRoomScreen(),
    );
  }
}

class ControlRoomScreen extends StatefulWidget {
  const ControlRoomScreen({super.key});

  @override
  State<ControlRoomScreen> createState() => _ControlRoomScreenState();
}

class _ControlRoomScreenState extends State<ControlRoomScreen> {
  static const List<FingerControl> _fingers = [
    FingerControl('index', 'Indice', Icons.back_hand_outlined),
    FingerControl('middle', 'Medio', Icons.pan_tool_alt_outlined),
    FingerControl('ring', 'Anulare', Icons.front_hand_outlined),
    FingerControl('pinky', 'Mignolo', Icons.waving_hand_outlined),
  ];

  static const List<GesturePreset> _presets = [
    GesturePreset('open_hand', 'Mano aperta', Icons.back_hand_outlined),
    GesturePreset('fist', 'Pugno', Icons.pan_tool),
    GesturePreset('pinch', 'Pinza', Icons.gesture),
    GesturePreset('ok', 'OK', Icons.check_circle_outline),
    GesturePreset('peace', 'Peace', Icons.sign_language_outlined),
    GesturePreset('simple_grip', 'Presa semplice', Icons.touch_app_outlined),
  ];

  final TextEditingController _baseUrlController = TextEditingController(
    text: 'http://10.0.2.2:8000',
  );
  final Map<String, double> _fingerValues = {
    'index': 100,
    'middle': 100,
    'ring': 100,
    'pinky': 100,
  };

  Timer? _pollTimer;
  String _baseUrl = 'http://10.0.2.2:8000';
  Map<String, dynamic>? _snapshot;
  String _lastPayload = const JsonEncoder.withIndent(
    '  ',
  ).convert({'command': 'ready'});
  String _lastResponse = 'In attesa';
  String? _error;
  bool _loadingState = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _fetchState();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _fetchState(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _baseUrlController.dispose();
    super.dispose();
  }

  ApiClient get _api => ApiClient(_baseUrl);

  Future<void> _fetchState({bool silent = false}) async {
    if (_loadingState) {
      return;
    }

    setState(() {
      _loadingState = true;
      if (!silent) {
        _error = null;
      }
    });

    try {
      final state = await _api.getState();
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = state;
        _error = null;
      });
    } catch (exception) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _friendlyError(exception);
      });
    } finally {
      if (mounted) {
        setState(() => _loadingState = false);
      }
    }
  }

  Future<void> _sendCommand(Map<String, dynamic> payload) async {
    setState(() {
      _sending = true;
      _error = null;
      _lastPayload = const JsonEncoder.withIndent('  ').convert(payload);
      _lastResponse = 'Invio in corso...';
    });

    try {
      final response = await _api.sendCommand(payload);
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = _asMap(response['state']) ?? _snapshot;
        _lastResponse = const JsonEncoder.withIndent(
          '  ',
        ).convert({'mqtt': response['mqtt'], 'command': response['data']});
      });
    } catch (exception) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _friendlyError(exception);
        _lastResponse = _error!;
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _applyBaseUrl() {
    final value = _baseUrlController.text.trim().replaceFirst(
      RegExp(r'/$'),
      '',
    );
    if (value.isEmpty) {
      return;
    }

    setState(() {
      _baseUrl = value;
      _snapshot = null;
      _error = null;
    });
    _fetchState();
  }

  void _setFingerValue(String finger, double value) {
    setState(() {
      _fingerValues[finger] = value;
    });
  }

  Map<String, dynamic>? get _status => _asMap(_snapshot?['status']);
  Map<String, dynamic>? get _telemetry => _asMap(_snapshot?['latestTelemetry']);
  Map<String, dynamic> get _currentFingers =>
      _asMap(_telemetry?['fingers']) ?? const {};

  bool get _isOnline =>
      (_status?['mqtt'] ?? '').toString().toLowerCase() == 'online';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hand Project'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: _loadingState ? null : () => _fetchState(),
            icon: _loadingState
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _HeaderPanel(
              mqttStatus: (_status?['mqtt'] ?? 'offline').toString(),
              handStatus: (_status?['hand'] ?? 'standby').toString(),
              lastUpdate:
                  (_status?['lastUpdate'] ??
                          _telemetry?['timestamp'] ??
                          'In attesa')
                      .toString(),
              online: _isOnline,
            ),
            const SizedBox(height: 14),
            _EndpointPanel(
              controller: _baseUrlController,
              onApply: _applyBaseUrl,
              error: _error,
            ),
            const SizedBox(height: 14),
            _Section(
              title: 'Controllo manuale',
              trailing: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _sending
                              ? null
                              : () => _sendCommand({'command': 'open_all'}),
                          icon: const Icon(Icons.keyboard_double_arrow_up),
                          label: const Text('Apri tutto'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _sending
                              ? null
                              : () => _sendCommand({'command': 'close_all'}),
                          icon: const Icon(Icons.keyboard_double_arrow_down),
                          label: const Text('Chiudi tutto'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final finger in _fingers) ...[
                    _FingerTile(
                      control: finger,
                      value: _fingerValues[finger.key] ?? 100,
                      currentPercent: _fingerPercent(finger.key),
                      enabled: !_sending,
                      onChanged: (value) => _setFingerValue(finger.key, value),
                      onRelease: () => _sendCommand({
                        'command': 'release_finger',
                        'finger': finger.key,
                        'targetPercentage': 0,
                      }),
                      onMove: () => _sendCommand({
                        'command': 'move_finger',
                        'finger': finger.key,
                        'targetPercentage': (_fingerValues[finger.key] ?? 100)
                            .round(),
                      }),
                    ),
                    if (finger != _fingers.last) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Section(
              title: 'Preset',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _presets.map((preset) {
                  return SizedBox(
                    width: MediaQuery.sizeOf(context).width > 440
                        ? (MediaQuery.sizeOf(context).width - 52) / 2
                        : double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _sending
                          ? null
                          : () => _sendCommand({
                              'command': 'gesture',
                              'gestureName': preset.key,
                            }),
                      icon: Icon(preset.icon),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          preset.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            _Section(
              title: 'Stato dita',
              child: Column(
                children: [
                  for (final finger in _fingers) ...[
                    _FingerStatusRow(
                      label: finger.label,
                      value: _fingerPercent(finger.key),
                    ),
                    if (finger != _fingers.last) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Section(
              title: 'Ultimo invio',
              child: _CodeBox(text: _lastPayload),
            ),
            const SizedBox(height: 14),
            _Section(
              title: 'Risposta API',
              child: _CodeBox(text: _lastResponse),
            ),
          ],
        ),
      ),
    );
  }

  int _fingerPercent(String finger) {
    final data = _asMap(_currentFingers[finger]);
    if (data == null) {
      return 0;
    }

    final value = data['percentage'];
    if (value is num) {
      return value.round().clamp(0, 100);
    }

    return int.tryParse(value.toString())?.clamp(0, 100) ?? 0;
  }

  String _friendlyError(Object exception) {
    final text = exception.toString();
    if (text.contains('Connection refused') ||
        text.contains('SocketException')) {
      return 'API non raggiungibile: controlla Laravel su $_baseUrl';
    }

    return text.replaceFirst('Exception: ', '');
  }
}

class ApiClient {
  ApiClient(this.baseUrl);

  final String baseUrl;
  static const Duration _timeout = Duration(seconds: 6);

  Future<Map<String, dynamic>> getState() {
    return _request('GET', '/api/state');
  }

  Future<Map<String, dynamic>> sendCommand(Map<String, dynamic> payload) {
    return _request('POST', '/api/commands', payload);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? payload,
  ]) async {
    final client = HttpClient()..connectionTimeout = _timeout;

    try {
      final uri = Uri.parse('$baseUrl$path');
      final request = await client.openUrl(method, uri).timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);

      if (payload != null) {
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(jsonEncode(payload)));
      }

      final response = await request.close().timeout(_timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);
      final decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message =
            decoded is Map<String, dynamic> && decoded['message'] != null
            ? decoded['message'].toString()
            : 'HTTP ${response.statusCode}';
        throw Exception(message);
      }

      return _asMap(decoded) ?? <String, dynamic>{};
    } finally {
      client.close(force: true);
    }
  }
}

class FingerControl {
  const FingerControl(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

class GesturePreset {
  const GesturePreset(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

class _HeaderPanel extends StatelessWidget {
  const _HeaderPanel({
    required this.mqttStatus,
    required this.handStatus,
    required this.lastUpdate,
    required this.online,
  });

  final String mqttStatus;
  final String handStatus;
  final String lastUpdate;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF121A21),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF25313A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF8FE6C4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.pan_tool_alt, color: Color(0xFF07110E)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hand Project',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Control room mobile',
                      style: TextStyle(color: Color(0xFFA9B6C2)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(label: 'MQTT', value: mqttStatus, active: online),
              _StatusPill(
                label: 'Mano',
                value: handStatus,
                active: handStatus.toLowerCase() != 'standby',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule, size: 18, color: Color(0xFFA9B6C2)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lastUpdate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFA9B6C2)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EndpointPanel extends StatelessWidget {
  const _EndpointPanel({
    required this.controller,
    required this.onApply,
    required this.error,
  });

  final TextEditingController controller;
  final VoidCallback onApply;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'API',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    prefixIcon: Icon(Icons.link),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => onApply(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                tooltip: 'Usa URL',
                onPressed: onApply,
                icon: const Icon(Icons.check),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: const TextStyle(color: Color(0xFFFF8A7A))),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121A21),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF25313A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _FingerTile extends StatelessWidget {
  const _FingerTile({
    required this.control,
    required this.value,
    required this.currentPercent,
    required this.enabled,
    required this.onChanged,
    required this.onRelease,
    required this.onMove,
  });

  final FingerControl control;
  final double value;
  final int currentPercent;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final VoidCallback onRelease;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF18212A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2B3742)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(control.icon, color: const Color(0xFF8FE6C4)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  control.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$currentPercent%',
                style: const TextStyle(
                  color: Color(0xFFA9B6C2),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 20,
            label: '${value.round()}%',
            onChanged: enabled ? onChanged : null,
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: enabled ? onRelease : null,
                  icon: const Icon(Icons.keyboard_arrow_up),
                  label: const Text('Rilascia'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: enabled ? onMove : null,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  label: Text('Piega ${value.round()}%'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FingerStatusRow extends StatelessWidget {
  const _FingerStatusRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: value / 100,
              backgroundColor: const Color(0xFF26313A),
              color: const Color(0xFF8FE6C4),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 42,
          child: Text(
            '$value%',
            textAlign: TextAlign.right,
            style: const TextStyle(color: Color(0xFFA9B6C2)),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.value,
    required this.active,
  });

  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF8FE6C4) : const Color(0xFFFF8A7A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: 8),
          Text(
            '$label ${value.toUpperCase()}',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF070B0E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF25313A)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText(
          text,
          style: const TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFFE9F4F1),
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, data) => MapEntry(key.toString(), data));
  }

  return null;
}
