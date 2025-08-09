// lib/main.dart
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        fontFamily: 'MochiyPopOne',
        textTheme: ThemeData.light().textTheme.apply(
          fontFamily: 'MochiyPopOne',
        ),
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
  String _selectedSound = 'click1.mp3'; // タップ音
  int? _goalCount = 10; // デフォルトで10回

  // タップ音ファイル（assets/sounds/ 配下）
  final List<String> _soundFiles = [
    'click1.mp3',
    'click2.mp3',
    'click3.mp3',
    'click4.mp3',
  ];

  // --- ゴール音一覧（ファイル名） ---
  final List<String> _goalSoundFiles = [
    'goal1.wav',
    'goal2.wav',
    'goal3.mp3',
    'goal4.mp3',
  ];

  // ファイル名 -> 表示名（UI用ラベル）
  final Map<String, String> _goalSoundLabels = {
    'goal1.wav': '友達のお知らせ',
    'goal2.wav': '友達の口笛',
    'goal3.mp3': '猫のたいぞう',
    'goal4.mp3': '猫のゴルバチョフ',
  };

  String _selectedGoalSound = 'goal1.wav'; // ゴール音のデフォルト

  // 保存済みカスタムゴール（永続化）
  List<int> _savedGoals = [];
  static const String _prefsSavedGoalsKey = 'saved_goals_v1';

  // セッション内達成履歴
  List<int> _achievedHistory = [];

  // AudioPlayer 管理
  final Map<String, AudioPlayer> _players = {};
  final Map<String, bool> _ready = {};

  void _log(String msg) => debugPrint('[CuteCounter] $msg');

  @override
  void initState() {
    super.initState();
    // タップ音プリロード
    for (final f in _soundFiles) {
      _ready[f] = false;
      _createAndPreload(f);
    }
    // ゴール音プリロード
    for (final f in _goalSoundFiles) {
      _ready[f] = false;
      _createAndPreload(f);
    }
    // 保存済みゴールロード
    _loadSavedGoals();
  }

  Future<void> _createAndPreload(String fileName) async {
    try {
      if (_players.containsKey(fileName)) {
        try {
          await _players[fileName]!.stop();
          await _players[fileName]!.dispose();
        } catch (_) {}
        _players.remove(fileName);
        _ready[fileName] = false;
      }

      final player = AudioPlayer();
      try {
        await player.setReleaseMode(ReleaseMode.stop);
      } catch (_) {}
      await player.setSource(AssetSource('sounds/$fileName'));
      _players[fileName] = player;
      _ready[fileName] = true;
      _log('プリロード完了: $fileName');
    } catch (e) {
      _ready[fileName] = false;
      _log('プリロード失敗: $fileName -> $e');
    }
  }

  Future<void> _ensurePreloaded(String fileName) async {
    if (_ready[fileName] == true && _players.containsKey(fileName)) return;
    await _createAndPreload(fileName);
  }

  void _increment() {
    setState(() {
      _count++;
    });

    _handleSoundAndVibration();
    _checkGoal();
  }

  Future<void> _handleSoundAndVibration() async {
    // バイブ
    try {
      if (_vibrationEnabled && (await Vibration.hasVibrator() ?? false)) {
        Vibration.vibrate(duration: 50);
      }
    } catch (e) {
      _log('Vibration error: $e');
    }

    // タップ音
    if (!_soundEnabled) return;
    final file = _selectedSound;
    if (!(_ready[file] == true && _players.containsKey(file))) {
      _log('再生前にプリロードが必要: $file (開始します)');
      _ensurePreloaded(file);
      return;
    }

    final player = _players[file]!;
    try {
      await player.seek(Duration.zero);
      await player.resume();
    } catch (e) {
      _log('音再生エラー(play/resume): $e — 再プリロードを試みます');
      await _createAndPreload(file);
    }
  }

  Future<void> _checkGoal() async {
    if (_goalCount != null && _count == _goalCount) {
      // バイブ（まとめ）
      try {
        if (_vibrationEnabled) {
          Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 200]);
        }
      } catch (e) {
        _log('Vibration error (goal): $e');
      }

      // ゴール音（タップ音とは別）
      if (_soundEnabled) {
        final file = _selectedGoalSound;
        if (!(_ready[file] == true && _players.containsKey(file))) {
          _log('ゴール時にプリロードが未完了: $file — プリロード開始');
          await _ensurePreloaded(file);
        }
        if (_ready[file] == true && _players.containsKey(file)) {
          final player = _players[file]!;
          try {
            await player.seek(Duration.zero);
            await player.resume();
          } catch (e) {
            _log('ゴール音再生エラー: $e');
            await _createAndPreload(file);
          }
        }
      }

      // 履歴に追加（セッション）
      setState(() {
        if (_goalCount != null) _achievedHistory.insert(0, _goalCount!);
      });

      // ユーザー通知
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('おめでとう！ ${_goalCount} 回達成しました🎉')));
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
    await _ensurePreloaded(newSound);
  }

  // --- SharedPreferences 操作 ---
  Future<void> _loadSavedGoals() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final List<String>? list = sp.getStringList(_prefsSavedGoalsKey);
      if (list != null) {
        setState(() {
          _savedGoals = list
              .map((s) => int.tryParse(s) ?? 0)
              .where((n) => n > 0)
              .toList();
          _savedGoals.sort();
        });
      }
    } catch (e) {
      _log('SavedGoals load error: $e');
    }
  }

  Future<void> _saveSavedGoals() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList(
        _prefsSavedGoalsKey,
        _savedGoals.map((i) => i.toString()).toList(),
      );
    } catch (e) {
      _log('SavedGoals save error: $e');
    }
  }

  // --- チップ UI ---
  Widget _goalChip(int? value, {String? label}) {
    final bool selected = _goalCount == value;
    final display = label ?? (value?.toString() ?? '設定なし');
    return InputChip(
      label: Text(display, style: TextStyle(color: Colors.white)),
      selected: selected,
      selectedColor: Colors.pink.shade400,
      backgroundColor: Colors.pink.shade200.withOpacity(0.6),
      onSelected: (_) {
        setState(() {
          _goalCount = value;
        });
        // チップ選択後にドロワーを閉じる（UX向上）
        Navigator.of(context).maybePop();
      },
      avatar: (value != null && _savedGoals.contains(value))
          ? GestureDetector(
              onTap: () => _confirmRemoveSavedGoal(value),
              child: Icon(Icons.delete, color: Colors.white, size: 18),
            )
          : null,
    );
  }

  // --- カスタム入力ダイアログ ---
  Future<bool> _applyCustomGoal(String text) async {
    final txt = text.trim();
    final n = int.tryParse(txt);
    if (n == null || n <= 0) return false;
    if (!_savedGoals.contains(n)) {
      setState(() {
        _savedGoals.add(n);
        _savedGoals.sort();
      });
      await _saveSavedGoals();
    }
    setState(() {
      _goalCount = n;
    });
    return true;
  }

  Future<void> _showCustomGoalDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('カスタムゴールを入力'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(hintText: '例: 23'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '数字を入力してください';
                final n = int.tryParse(v.trim());
                if (n == null || n <= 0) return '正の整数を入力してください';
                return null;
              },
              onFieldSubmitted: (_) async {
                if (formKey.currentState?.validate() == true) {
                  final ok = await _applyCustomGoal(controller.text);
                  if (ok) Navigator.of(context).pop();
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('キャンセル'),
            ),
            TextButton(
              onPressed: () async {
                if (formKey.currentState?.validate() == true) {
                  final ok = await _applyCustomGoal(controller.text);
                  if (ok) Navigator.of(context).pop();
                }
              },
              child: Text('保存＆選択'),
            ),
          ],
        );
      },
    );
  }

  // --- 保存済みゴールの削除確認 ---
  Future<void> _confirmRemoveSavedGoal(int val) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('削除しますか？'),
        content: Text('$val を保存リストから削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _savedGoals.remove(val);
      });
      _saveSavedGoals();
    }
  }

  @override
  void dispose() {
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
              colors: [
                Color(0xFFFF92B6),
                Colors.pink.shade100,
                Colors.pink.shade300,
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
                        fontFamily: 'MochiyPopOne',
                        color: Colors.white,
                        fontSize: 24,
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

                SwitchListTile(
                  title: Text('バイブをならす', style: TextStyle(color: Colors.white)),
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
                    'クリック音をならす',
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
                    'タップ音をえらぶ',
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

                // --- ゴール音選択（表示名を使う） ---
                ListTile(
                  title: Text(
                    'ゴール音をえらぶ',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    _goalSoundLabels[_selectedGoalSound] ?? _selectedGoalSound,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    dropdownColor: Colors.pink.shade200,
                    value: _selectedGoalSound,
                    items: _goalSoundFiles.map((sound) {
                      final label = _goalSoundLabels[sound] ?? sound;
                      return DropdownMenuItem<String>(
                        value: sound,
                        child: Text(
                          label,
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? value) async {
                      if (value != null) {
                        setState(() {
                          _selectedGoalSound = value;
                        });
                        await _ensurePreloaded(value);
                      }
                    },
                  ),
                ),

                // --- カスタム追加対応のゴール選択エリア ---
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ゴールの回数', style: TextStyle(color: Colors.white)),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _goalChip(null, label: '設定なし'),
                          _goalChip(10),
                          _goalChip(20),
                          _goalChip(50),
                          _goalChip(100),
                          ..._savedGoals.map((g) => _goalChip(g)).toList(),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _showCustomGoalDialog(),
                            icon: Icon(Icons.add, color: Colors.white),
                            label: Text(
                              'カスタムを追加',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pink.shade300,
                            ),
                          ),
                          SizedBox(width: 8),
                          if (_savedGoals.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _savedGoals.clear();
                                });
                                _saveSavedGoals();
                              },
                              child: Text(
                                '全部削除',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'アイコンや効果音の設定はここで切り替えられます。',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                SizedBox(height: 12),

                Center(
                  child: InkWell(
                    onTap: () async {
                      final uri = Uri.parse('https://otologic.jp');
                      if (!await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      )) {
                        debugPrint('Could not launch $uri');
                      }
                    },
                    child: Text(
                      '効果音提供 オトロジック(https://otologic.jp)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'MochiyPopOne',
                      ),
                    ),
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
                  ],
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
                  surfaceTintColor: Colors.transparent,
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
                  'カウント',
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
