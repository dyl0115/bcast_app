import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(const BcastApp());
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
  final _player = AudioPlayer();
  final _urlController = TextEditingController(text: 'https://doubledragon.duckdns.org/bcast/stream');

  bool _isConnected = false;
  bool _isBuffering = false;
  String _status = '연결 안됨';

  @override
  void initState() {
    super.initState();
    _player.playerStateStream.listen(_onPlayerState);
  }

  void _onPlayerState(PlayerState state) {
    setState(() {
      switch (state.processingState) {
        case ProcessingState.loading:
        case ProcessingState.buffering:
          _isBuffering = true;
          _status = '버퍼링 중...';
        case ProcessingState.ready:
          _isBuffering = false;
          _status = state.playing ? '방송 수신 중' : '일시 정지';
        case ProcessingState.completed:
        case ProcessingState.idle:
          _isBuffering = false;
          _isConnected = false;
          _status = '연결 안됨';
      }
    });
  }

  Future<void> _connect() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isConnected = true;
      _status = '연결 중...';
    });

    try {
      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      setState(() {
        _isConnected = false;
        _status = '연결 실패: $e';
      });
    }
  }

  Future<void> _disconnect() async {
    await _player.stop();
    setState(() {
      _isConnected = false;
      _status = '연결 안됨';
    });
  }

  @override
  void dispose() {
    _player.dispose();
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
              _status,
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
                onPressed: _isBuffering ? null : (_isConnected ? _disconnect : _connect),
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
