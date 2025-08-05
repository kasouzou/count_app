import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(MyCuteCounterApp());
}

class MyCuteCounterApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cute Counter',
      theme: ThemeData(primarySwatch: Colors.pink),
      home: CounterPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CounterPage extends StatefulWidget {
  @override
  _CounterPageState createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int _count = 0;
  bool _vibrationEnabled = true;
  bool _soundEnabled = true;
  String _selectedSound = 'click1.mp3'; // ファイル名だけ
  int? _goalCount = 10; // デフォルトで10回

  late AudioPlayer _audioPlayer;
  bool _isSoundReady = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _preloadSound(_selectedSound);
  }

  Future<void> _preloadSound(String soundFile) async {
    try {
      await _audioPlayer.setSource(AssetSource('sounds/$soundFile'));
      _isSoundReady = true;
    } catch (e) {
      debugPrint('音声プリロード失敗: $e');
      _isSoundReady = false;
    }
  }

  void _increment() {
    // まずUIのカウントを即更新
    setState(() {
      _count++;
    });

    // 以降の処理は非同期にまとめて並行実行
    _handleSoundAndVibration();
    _checkGoal();
  }

  Future<void> _handleSoundAndVibration() async {
    // バイブは速いので即呼び出しでOK
    if (_vibrationEnabled && await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 50);
    }

    if (_soundEnabled) {
      if (!_isSoundReady) {
        // プリロードがまだなら裏で始めるだけ（再生はスキップ）
        await _preloadSound(_selectedSound);
        return;
      }
      try {
        // 音はプリロード済みなので再生する
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play(AssetSource('sounds/$_selectedSound'));
      } catch (e) {
        debugPrint('音再生エラー: $e');
      }
    }
  }

  Future<void> _checkGoal() async {
    if (_goalCount != null && _count == _goalCount) {
      if (_vibrationEnabled) {
        Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 200]);
      }
      if (_soundEnabled && _isSoundReady) {
        try {
          await _audioPlayer.seek(Duration.zero);
          await _audioPlayer.play(AssetSource('sounds/$_selectedSound'));
          await Future.delayed(Duration(milliseconds: 300));
          await _audioPlayer.seek(Duration.zero);
          await _audioPlayer.play(AssetSource('sounds/$_selectedSound'));
        } catch (e) {
          debugPrint('ゴール音再生エラー: $e');
        }
      }
    }
  }

  Future<void> _reset() async {
    setState(() {
      _count = 0;
    });
  }

  Future<void> _changeSound(String newSound) async {
    setState(() {
      _selectedSound = newSound;
      _isSoundReady = false;
    });
    await _preloadSound(newSound);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final double fontSize = isPortrait ? 100 : 60;
    final double resetButtonHeight = isPortrait ? 80 : 60;

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.pinkAccent),
              child: Text(
                '設定',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            SwitchListTile(
              title: Text('バイブを鳴らす'),
              value: _vibrationEnabled,
              activeColor: Colors.pink,
              onChanged: (bool value) {
                setState(() {
                  _vibrationEnabled = value;
                });
              },
            ),
            SwitchListTile(
              title: Text('クリック音を鳴らす'),
              value: _soundEnabled,
              activeColor: Colors.pink,
              onChanged: (bool value) {
                setState(() {
                  _soundEnabled = value;
                });
              },
            ),
            ListTile(
              title: Text('クリック音を選ぶ'),
              trailing: DropdownButton<String>(
                value: _selectedSound,
                items: ['click1.mp3', 'click2.mp3', 'click3.mp3', 'click4.mp3']
                    .map((sound) {
                      return DropdownMenuItem(value: sound, child: Text(sound));
                    })
                    .toList(),
                onChanged: (String? value) {
                  if (value != null) {
                    _changeSound(value);
                  }
                },
              ),
            ),
            ListTile(
              title: Text('ゴールの回数'),
              subtitle: Text(_goalCount?.toString() ?? '設定なし'),
              trailing: DropdownButton<int?>(
                value: _goalCount,
                items: [null, 10, 20, 50, 100].map((count) {
                  return DropdownMenuItem(
                    value: count,
                    child: Text(count?.toString() ?? '設定なし'),
                  );
                }).toList(),
                onChanged: (int? value) {
                  setState(() {
                    _goalCount = value;
                  });
                },
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text('Cute Counter'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink.shade100, Colors.pink.shade200],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).padding.top + kToolbarHeight,
            ),
            Container(
              width: double.infinity,
              height: resetButtonHeight,
              margin: EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: _reset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'リセット',
                  style: TextStyle(
                    fontSize: isPortrait ? 24 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$_count',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.pink.shade900,
                        offset: Offset(3.0, 3.0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              height:
                  MediaQuery.of(context).size.height *
                  (isPortrait ? 0.4 : 0.25),
              child: ElevatedButton(
                onPressed: _increment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                  elevation: 6,
                ),
                child: Text(
                  'カウント！',
                  style: TextStyle(
                    fontSize: isPortrait ? 30 : 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 5.0,
                        color: Colors.pink.shade900,
                        offset: Offset(2.0, 2.0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
