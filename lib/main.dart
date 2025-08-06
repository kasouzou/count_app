import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(MyCuteCounterApp());
}

class MyCuteCounterApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cute Counter',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        // ここでデフォルトのフォントを KaiseiDecol にする
        fontFamily: 'KaiseiDecol',
        // (必要なら textTheme を微調整)
        textTheme: ThemeData.light().textTheme.apply(fontFamily: 'KaiseiDecol'),
      ),
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

  // サウンドファイル一覧（assets/sounds/配下）
  final List<String> _soundFiles = [
    'click1.mp3',
    'click2.mp3',
    'click3.mp3',
    'click4.mp3',
  ];

  // ファイル名 -> AudioPlayer のマップ
  final Map<String, AudioPlayer> _players = {};
  // ファイル名 -> プリロード完了フラグ
  final Map<String, bool> _ready = {};

  // 簡易デバッグログ（必要ならexpand）
  void _log(String msg) => debugPrint('[CuteCounter] $msg');

  @override
  void initState() {
    super.initState();
    // 起動時に全部プリロードを開始（非同期で行う）
    for (final f in _soundFiles) {
      _ready[f] = false;
      _createAndPreload(f);
    }
  }

  Future<void> _createAndPreload(String fileName) async {
    try {
      // 既にプレイヤーがいるなら dispose して再作成（安全策）
      if (_players.containsKey(fileName)) {
        try {
          await _players[fileName]!.stop();
          await _players[fileName]!.dispose();
        } catch (_) {}
        _players.remove(fileName);
        _ready[fileName] = false;
      }

      final player = AudioPlayer();
      // 再生終了後は停止にしておく（連続再生の扱いを明確に）
      try {
        await player.setReleaseMode(ReleaseMode.stop);
      } catch (_) {}
      // プリロード（AssetSource をセット）
      await player.setSource(AssetSource('sounds/$fileName'));
      _players[fileName] = player;
      _ready[fileName] = true;
      _log('プリロード完了: $fileName');
    } catch (e) {
      _ready[fileName] = false;
      _log('プリロード失敗: $fileName -> $e');
    }
  }

  // 必要に応じて選択ファイルだけプリロードするユーティリティ
  Future<void> _ensurePreloaded(String fileName) async {
    if (_ready[fileName] == true && _players.containsKey(fileName)) return;
    await _createAndPreload(fileName);
  }

  void _increment() {
    // UIは即時更新（ユーザー感触を優先）
    setState(() {
      _count++;
    });

    // 非同期で音と振動を処理（UIはブロックしない）
    _handleSoundAndVibration();
    _checkGoal();
  }

  Future<void> _handleSoundAndVibration() async {
    // 1) バイブは先に行う（速い）
    try {
      if (_vibrationEnabled && (await Vibration.hasVibrator() ?? false)) {
        Vibration.vibrate(duration: 50);
      }
    } catch (e) {
      _log('Vibration error: $e');
    }

    // 2) 音
    if (!_soundEnabled) return;

    final file = _selectedSound;

    // もしまだプリロードされていなければ非同期でプリロード開始して再生はスキップする（次回は鳴る）
    if (!(_ready[file] == true && _players.containsKey(file))) {
      _log('再生前にプリロードが必要: $file (開始します)');
      // ここは待たずにバックグラウンドで始める（遅延を避けるため）
      _ensurePreloaded(file);
      return;
    }

    final player = _players[file]!;
    try {
      // 先頭に戻して resume（setSource は既に済）
      await player.seek(Duration.zero);
      await player.resume();
    } catch (e) {
      _log('音再生エラー(play/resume): $e — 再プリロードを試みます');
      // 失敗したら再プリロードして次回に備える
      await _createAndPreload(file);
    }
  }

  Future<void> _checkGoal() async {
    if (_goalCount != null && _count == _goalCount) {
      // ゴール時のまとめ振動（pattern）
      try {
        if (_vibrationEnabled) {
          Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 200]);
        }
      } catch (e) {
        _log('Vibration error (goal): $e');
      }

      // ゴール音はできるだけ鳴らす（プリロード済みなら鳴らす）
      if (_soundEnabled) {
        final file = _selectedSound;
        if (!(_ready[file] == true && _players.containsKey(file))) {
          _log('ゴール時にプリロードが未完了: $file');
          await _ensurePreloaded(file); // 後続に備える
          return;
        }
        final player = _players[file]!;
        try {
          await player.seek(Duration.zero);
          await player.resume();
          await Future.delayed(Duration(milliseconds: 300));
          await player.seek(Duration.zero);
          await player.resume();
        } catch (e) {
          _log('ゴール音再生エラー: $e');
          await _createAndPreload(file);
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
    });
    // 変更したファイルを確実にプリロード（非同期で行う）
    await _ensurePreloaded(newSound);
  }

  @override
  void dispose() {
    // 全プレイヤーを破棄
    for (final p in _players.values) {
      try {
        p.dispose();
      } catch (_) {}
    }
    _players.clear();
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
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              // カウントボタンやリセットのグラデと近い色合いに揃える
              colors: [
                Color(0xFFFF92B6), // 上寄りのピンク（例）
                Colors.pink.shade100, // 中間の薄ピンク
                Colors.pink.shade300, // 下寄りのピンク
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.45, 1.0],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Headerもグラデか透明にして一体感を強める
                DrawerHeader(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color.fromARGB(255, 252, 146, 182),
                        Colors.pink.shade100,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      '設定',
                      style: TextStyle(
                        fontFamily: 'KaiseiDecol',
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.pink.shade900.withOpacity(0.6),
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 各タイルを透明にして背景のグラデを生かす
                SwitchListTile(
                  title: Text('バイブを鳴らす', style: TextStyle(color: Colors.white)),
                  value: _vibrationEnabled,
                  activeColor: Colors.white,
                  activeTrackColor: Colors.pink.shade200,
                  onChanged: (bool value) {
                    setState(() {
                      _vibrationEnabled = value;
                    });
                  },
                  secondary: Icon(Icons.vibration, color: Colors.white),
                ),

                SwitchListTile(
                  title: Text(
                    'クリック音を鳴らす',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: _soundEnabled,
                  activeColor: Colors.white,
                  activeTrackColor: Colors.pink.shade200,
                  onChanged: (bool value) async {
                    setState(() {
                      _soundEnabled = value;
                    });
                    if (value) {
                      await _ensurePreloaded(_selectedSound);
                    }
                  },
                  secondary: Icon(Icons.music_note, color: Colors.white),
                ),

                ListTile(
                  title: Text(
                    'クリック音を選ぶ',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: DropdownButton<String>(
                    dropdownColor: Colors.pink.shade200,
                    value: _selectedSound,
                    items: _soundFiles
                        .map(
                          (sound) => DropdownMenuItem(
                            value: sound,
                            child: Text(
                              sound,
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      if (value != null) _changeSound(value);
                    },
                  ),
                ),

                ListTile(
                  title: Text('ゴールの回数', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    _goalCount?.toString() ?? '設定なし',
                    style: TextStyle(color: Colors.white70),
                  ),
                  trailing: DropdownButton<int?>(
                    dropdownColor: Colors.pink.shade200,
                    value: _goalCount,
                    items: [null, 10, 20, 50, 100].map((count) {
                      return DropdownMenuItem(
                        value: count,
                        child: Text(
                          count?.toString() ?? '設定なし',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (int? value) {
                      setState(() {
                        _goalCount = value;
                      });
                    },
                  ),
                ),

                // 余白（必要に応じて設定ボタンや説明を追加）
                SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'アイコンや効果音の設定はここで切り替えられます。',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      appBar: AppBar(
        title: Text(''),
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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color.fromARGB(255, 255, 144, 181),
                    Colors.pink.shade100,
                  ], // 薄めピンク
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: ElevatedButton(
                onPressed: _reset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent, // ← Material3ならこれで灰色消える
                  elevation: 0,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.pink.shade100, Colors.pink.shade300],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: ElevatedButton(
                onPressed: _increment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
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
