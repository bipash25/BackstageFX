import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:backstagefx/data/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: BackstageFXApp()));
}

/// Root app with dark theme and large tap targets for stage lighting.
class BackstageFXApp extends ConsumerWidget {
  const BackstageFXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blueGrey,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      visualDensity: VisualDensity.comfortable,
    );
    return MaterialApp(
      title: 'BackstageFX',
      theme: theme,
      home: const ConsoleScreen(),
    );
  }
}

/// Minimal audio engine:
/// - Default loop track with fade-in/out
/// - Master volume
/// - Emergency stop
/// - Quick anchor duck (temporary fade down and back up)
class AudioEngine {
  final AudioPlayer defaultPlayer = AudioPlayer();
  final AudioPlayer trackPlayer = AudioPlayer(); // reserved for performance tracks

  double _masterVolume = 0.8;
  bool _locked = false;
  double _lastUserVolume = 0.8;

  Future<void> init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await defaultPlayer.setVolume(_masterVolume);
    await trackPlayer.setVolume(_masterVolume);
  }

  Future<void> dispose() async {
    await defaultPlayer.dispose();
    await trackPlayer.dispose();
  }

  bool get locked => _locked;
  void setLocked(bool value) {
    _locked = value;
  }

  double get masterVolume => _masterVolume;
  Future<void> setMasterVolume(double v) async {
    _masterVolume = v.clamp(0.0, 1.0);
    await defaultPlayer.setVolume(_masterVolume);
    await trackPlayer.setVolume(_masterVolume);
  }

  Future<void> setDefaultSource(String path) async {
    await defaultPlayer.setAudioSource(AudioSource.uri(Uri.file(path)));
    await defaultPlayer.setLoopMode(LoopMode.one);
  }

  Future<void> playDefault({Duration fadeIn = const Duration(milliseconds: 1500)}) async {
    if (_locked) return;
    if (defaultPlayer.audioSource == null) return;
    await defaultPlayer.setVolume(0.0);
    await defaultPlayer.play();
    await _fadeTo(defaultPlayer, _masterVolume, fadeIn);
  }

  Future<void> fadeOutDefault({Duration fadeOut = const Duration(milliseconds: 1500)}) async {
    if (defaultPlayer.playing) {
      await _fadeTo(defaultPlayer, 0.0, fadeOut);
      await defaultPlayer.pause();
    }
  }

  Future<void> emergencyStop() async {
    await defaultPlayer.stop();
    await trackPlayer.stop();
  }

  Future<void> duckForAnchor({
    double duckLevel = 0.2,
    Duration duration = const Duration(seconds: 4),
    Duration fade = const Duration(milliseconds: 400),
  }) async {
    if (!defaultPlayer.playing) return;
    _lastUserVolume = _masterVolume;
    final target = (_lastUserVolume * duckLevel).clamp(0.0, 1.0);
    await _fadeTo(defaultPlayer, target, fade);
    await Future.delayed(duration);
    if (defaultPlayer.playing) {
      await _fadeTo(defaultPlayer, _lastUserVolume, fade);
    }
  }

  Future<void> _fadeTo(AudioPlayer player, double target, Duration duration) async {
    const steps = 20;
    final start = player.volume;
    final delta = (target - start) / steps;
    final tick = (duration.inMilliseconds / steps).round();
    for (var i = 1; i <= steps; i++) {
      final next = (start + delta * i).clamp(0.0, 1.0);
      await player.setVolume(next);
      await Future.delayed(Duration(milliseconds: tick));
    }
  }
}

/// Providers
final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = AudioEngine();
  // Fire and forget init; safe for startup.
  engine.init();
  ref.onDispose(() {
    engine.dispose();
  });
  return engine;
});

final soundLockProvider = StateProvider<bool>((ref) => false);
final masterVolumeProvider = StateProvider<double>((ref) => 0.8);

/// Big-button console for MVP operations.
class ConsoleScreen extends ConsumerStatefulWidget {
  const ConsoleScreen({super.key});

  @override
  ConsumerState<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends ConsumerState<ConsoleScreen> {
  bool _hasDefault = false;
  String? _defaultPath;
  StorageService? _storage;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    // Keep screen awake during operation.
    WakelockPlus.enable();

    _storage = ref.read(storageServiceProvider);
    final engine = ref.read(audioEngineProvider);

    _bindListeners(engine);
    // Load persisted state and restore engine.
    // Fire-and-forget; UI updates via providers.
    // ignore: discarded_futures
    _loadState(engine);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    // Optionally disable after leaving console.
    // WakelockPlus.disable();
    super.dispose();
  }

  void _bindListeners(AudioEngine engine) {
    ref.listen<bool>(soundLockProvider, (prev, next) {
      engine.setLocked(next);
      _scheduleSave();
    });
    ref.listen<double>(masterVolumeProvider, (prev, next) async {
      await engine.setMasterVolume(next);
      _scheduleSave();
    });
  }

  Future<void> _loadState(AudioEngine engine) async {
    try {
      final saved = await _storage!.load();
      // Apply saved state to providers and engine.
      ref.read(soundLockProvider.notifier).state = saved.locked;
      ref.read(masterVolumeProvider.notifier).state = saved.masterVolume;
      await engine.setMasterVolume(saved.masterVolume);
      engine.setLocked(saved.locked);
      if (saved.defaultTrackPath != null) {
        _defaultPath = saved.defaultTrackPath;
        await engine.setDefaultSource(saved.defaultTrackPath!);
        if (mounted) {
          setState(() {
            _hasDefault = true;
          });
        }
      }
    } catch (_) {
      // Safe to ignore; defaults already set.
    }
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), () async {
      final state = SavedState(
        masterVolume: ref.read(masterVolumeProvider),
        locked: ref.read(soundLockProvider),
        defaultTrackPath: _defaultPath,
      );
      // ignore: discarded_futures
      _storage?.save(state);
    });
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(audioEngineProvider);
    final locked = ref.watch(soundLockProvider);
    final masterVolume = ref.watch(masterVolumeProvider);

    Future<void> loadDefault() async {
      if (locked) return;
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: false,
      );
      final picked = (result != null && result.files.isNotEmpty) ? result.files.first : null;
      final path = picked?.path;
      if (path != null) {
        try {
          await engine.setDefaultSource(path);
          if (!context.mounted) return;
          setState(() {
            _hasDefault = true;
            _defaultPath = path;
          });
          _scheduleSave();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Default track loaded.')),
          );
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load: $e')),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('BackstageFX Console'),
        actions: [
          Row(
            children: [
              const Text('Lock', style: TextStyle(fontSize: 16)),
              Switch(
                value: locked,
                onChanged: (v) {
                  ref.read(soundLockProvider.notifier).state = v;
                  engine.setLocked(v);
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Load default background music
            _BigActionButton(
              label: 'Load Default Track',
              icon: Icons.library_music,
              color: Colors.blueGrey,
              onPressed: locked ? null : loadDefault,
            ),
            const SizedBox(height: 12),

            // Play/Pause default with fades
            Row(
              children: [
                Expanded(
                  child: _BigActionButton(
                    label: 'Play Default (Fade In)',
                    icon: Icons.play_arrow,
                    color: Colors.green.shade700,
                    onPressed: (!locked && _hasDefault)
                        ? () => engine.playDefault()
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BigActionButton(
                    label: 'Fade Out Default',
                    icon: Icons.stop_circle_outlined,
                    color: Colors.orange.shade700,
                    onPressed: (!locked) ? () => engine.fadeOutDefault() : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Anchor quick fade
            _BigActionButton(
              label: 'Anchor Speak (Quick Fade)',
              icon: Icons.mic_none,
              color: Colors.indigo,
              onPressed: (!locked) ? () => engine.duckForAnchor() : null,
            ),
            const SizedBox(height: 12),

            // Master volume
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Master Volume', style: TextStyle(fontSize: 18)),
                    Row(
                      children: [
                        const Icon(Icons.volume_down),
                        Expanded(
                          child: Slider(
                            value: masterVolume,
                            onChanged: locked
                                ? null
                                : (v) async {
                                    ref.read(masterVolumeProvider.notifier).state = v;
                                    await engine.setMasterVolume(v);
                                  },
                          ),
                        ),
                        const Icon(Icons.volume_up),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Countdown placeholder (MVP wiring)
            Card(
              child: ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('Countdown'),
                subtitle: const Text('Scheduled start and timers will appear here.'),
                trailing: ElevatedButton(
                  onPressed: null, // placeholder
                  child: const Text('Set'),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Emergency Stop
            _BigActionButton(
              label: 'EMERGENCY STOP',
              icon: Icons.warning_amber_rounded,
              color: Colors.red.shade800,
              onPressed: () => engine.emergencyStop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _BigActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 28),
      label: Text(label),
    );
  }
}
