import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';

late BcastAudioHandler _audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _audioHandler = await AudioService.init(
    builder: () => BcastAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.dyl0115.bcast_app.audio',
      androidNotificationChannelName: 'Bcast 라디오',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: false,
    ),
  );
  runApp(const BcastApp());
}

class BcastAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();
  bool _shouldConnect = false;

  static const _baseItem = MediaItem(
    id: 'bcast_live',
    title: 'Bcast',
    artist: '연결 안됨',
  );

  BcastAudioHandler() {
    mediaItem.add(_baseItem);
    _player.playerStateStream.listen(_onPlayerState);
  }

  void _onPlayerState(PlayerState ps) {
    if (ps.processingState == ProcessingState.idle) return;

    if (ps.processingState == ProcessingState.completed) {
      if (_shouldConnect) stop();
      return;
    }

    final audioState = switch (ps.processingState) {
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      _ => AudioProcessingState.idle,
    };

    final artist = switch ((ps.processingState, ps.playing)) {
      (ProcessingState.loading, _) || (ProcessingState.buffering, _) => '버퍼링 중...',
      (ProcessingState.ready, true) => '방송 수신 중',
      (ProcessingState.ready, false) => '일시 정지',
      _ => '연결 중...',
    };

    mediaItem.add(_baseItem.copyWith(artist: artist));
    playbackState.add(playbackState.value.copyWith(
      controls: [
        if (ps.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.play, MediaAction.pause, MediaAction.stop},
      androidCompactActionIndices: const [0],
      processingState: audioState,
      playing: ps.playing,
    ));
  }

  void _emitLoadingState(String artist) {
    mediaItem.add(_baseItem.copyWith(artist: artist));
    playbackState.add(playbackState.value.copyWith(
      controls: [MediaControl.stop],
      systemActions: const {MediaAction.stop},
      androidCompactActionIndices: const [0],
      processingState: AudioProcessingState.loading,
      playing: false,
    ));
  }

  Future<void> connectAndPlay(String url) async {
    _shouldConnect = true;
    _emitLoadingState('연결 중...');

    while (_shouldConnect) {
      try {
        await _player.setUrl(url);
        if (!_shouldConnect) break;
        await _player.play();
        return;
      } catch (_) {
        if (!_shouldConnect) break;
        _emitLoadingState('방송 대기 중...');
        await Future.delayed(const Duration(seconds: 3));
      }
    }
  }

  @override
  Future<void> play() async {
    if (_player.processingState == ProcessingState.ready) {
      await _player.play();
    }
  }

  @override
  Future<void> pause() => stop();

  @override
  Future<void> stop() async {
    _shouldConnect = false;
    await _player.stop();
    mediaItem.add(_baseItem.copyWith(artist: '연결 안됨'));
    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() => stop();

  @override
  Future<void> onNotificationDeleted() => stop();
}

class BcastApp extends StatelessWidget {
  const BcastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bcast',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: Colors.deepPurple),
      ),
      home: const PlayerScreen(),
    );
  }
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _urlController = TextEditingController(
    text: 'https://doubledragon.duckdns.org/bcast/stream',
  );

  late StreamSubscription<PlaybackState> _stateSub;
  late StreamSubscription<MediaItem?> _mediaSub;

  AudioProcessingState _processingState = AudioProcessingState.idle;
  String _statusText = '연결 안됨';

  bool get _isConnected => _processingState != AudioProcessingState.idle;
  bool get _isBuffering =>
      _processingState == AudioProcessingState.loading ||
      _processingState == AudioProcessingState.buffering;

  @override
  void initState() {
    super.initState();
    _stateSub = _audioHandler.playbackState.listen((state) {
      setState(() => _processingState = state.processingState);
    });
    _mediaSub = _audioHandler.mediaItem.listen((item) {
      setState(() => _statusText = item?.artist ?? '연결 안됨');
    });
  }

  void _connect() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    _audioHandler.connectAndPlay(url);
  }

  @override
  void dispose() {
    _stateSub.cancel();
    _mediaSub.cancel();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Bcast', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF16213E),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatusIcon(isConnected: _isConnected, isBuffering: _isBuffering),
            const SizedBox(height: 20),
            Text(
              _statusText,
              style: TextStyle(
                fontSize: 18,
                color: _isConnected ? Colors.deepPurpleAccent : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 48),
            TextField(
              controller: _urlController,
              enabled: !_isConnected,
              keyboardType: TextInputType.url,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: '서버 URL',
                hintText: 'http://192.168.0.1:8336/stream',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFF16213E),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isConnected ? _audioHandler.stop : _connect,
                icon: Icon(_isConnected ? Icons.stop_rounded : Icons.play_arrow_rounded),
                label: Text(
                  _isConnected ? '연결 끊기' : '수신 시작',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _isConnected ? Colors.red[800] : Colors.deepPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final bool isConnected;
  final bool isBuffering;

  const _StatusIcon({required this.isConnected, required this.isBuffering});

  @override
  Widget build(BuildContext context) {
    if (isBuffering) {
      return const SizedBox(
        width: 80,
        height: 80,
        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.deepPurpleAccent),
      );
    }
    return Icon(
      isConnected ? Icons.radio : Icons.radio_outlined,
      size: 80,
      color: isConnected ? Colors.deepPurpleAccent : Colors.grey[600],
    );
  }
}
