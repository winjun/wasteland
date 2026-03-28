import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../game/game_state.dart';
import '../models/enemy.dart';
import '../models/weapon.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // ── 자이로스코프 상태 ─────────────────────────
  // 조준점 위치 (0~1). 폰이 수평이면 (0.5, 0.5) = 화면 중앙
  double _aimX = 0.5;
  double _aimY = 0.5;

  // 자이로 보정 기준값 (처음 내다볼 때 현재 기울기를 0으로 잡음)
  double _gyroBaseX = 0.0;
  double _gyroBaseY = 0.0;
  bool   _gyroCalibrated = false;

  // 가속도 센서 값 (중력 기반 기울기 측정)
  double _accelX = 0.0;
  double _accelY = 0.0;

  // 웹 fallback: 드래그로 조준
  bool   _isSensorAvailable = true;
  Offset _dragAim = const Offset(0.5, 0.5);

  @override
  void initState() {
    super.initState();
    _initSensors();
  }

  void _initSensors() {
    try {
      accelerometerEventStream().listen((event) {
        if (!mounted) return;
        _accelX = event.x;  // 좌우 기울기: 오른쪽 기울면 양수
        _accelY = event.y;  // 앞뒤 기울기: 앞으로 기울면 음수
        _updateAimFromAccel();
      });
    } catch (_) {
      // 웹/에뮬레이터 등 센서 없는 환경
      setState(() => _isSensorAvailable = false);
    }
  }

  void _calibrateGyro() {
    // 현재 기울기를 "중립"으로 설정
    _gyroBaseX    = _accelX;
    _gyroBaseY    = _accelY;
    _gyroCalibrated = true;
    _aimX = 0.5;
    _aimY = 0.5;
  }

  void _updateAimFromAccel() {
    if (!_gyroCalibrated) return;
    // 기준값 대비 변화량으로 조준점 이동
    // 민감도: 기울기 1 단위 = 조준점 0.12 이동
    const sensitivity = 0.12;
    final dx = (_accelX - _gyroBaseX) * sensitivity;
    final dy = (_accelY - _gyroBaseY) * sensitivity;

    // 왼쪽 기울기 → 조준선 왼쪽 / 오른쪽 기울기 → 오른쪽
    // 앞으로 기울기 → 조준선 위 / 뒤로 기울기 → 아래
    final newX = (0.5 - dx).clamp(0.05, 0.95);
    final newY = (0.5 + dy).clamp(0.05, 0.95);

    _aimX = newX;
    _aimY = newY;

    // GameState에 조준값 반영
    if (mounted) {
      context.read<GameState>().updateAim(_aimX, _aimY);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final isPeeking = state.cameraMode == CameraMode.peeking;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // ── 배경 레이어 ───────────────────────
        _buildBackground(state, isPeeking),

        // ── 엄폐물 레이어 (항상 표시) ─────────
        _CoverLayer(isPeeking: isPeeking, vehicle: state.currentVehicle),

        // ── 게임 콘텐츠 (내다볼 때만 표시) ────
        if (isPeeking) ...[
          _EnemiesLayer(state: state),
          _BulletsLayer(state: state),
          // 4x5 그리드 + 조준선 (적과 같은 셀이면 빨간색)
          _GridCrosshairLayer(
            aimX: _isSensorAvailable ? _aimX : _dragAim.dx,
            aimY: _isSensorAvailable ? _aimY : _dragAim.dy,
            hasEnemy: state.aimData.hasEnemyInCell,
            gridCol:  state.aimData.gridCol,
            gridRow:  state.aimData.gridRow,
          ),
        ],

        // ── HUD ──────────────────────────────
        _HudLayer(state: state),

        // ── 효과 오버레이 ─────────────────────
        _EffectsLayer(state: state),

        // ── 드래그 조준 (센서 없는 환경) ───────
        if (!_isSensorAvailable && isPeeking)
          _DragAimOverlay(
            onUpdate: (o) {
              setState(() => _dragAim = o);
              context.read<GameState>().updateAim(o.dx, o.dy);
            },
          ),

        // ── 컨트롤 버튼 ──────────────────────
        _ControlsLayer(
          state: state,
          isPeeking: isPeeking,
          onPeekStart: () {
            _calibrateGyro();
            context.read<GameState>().startPeek();
          },
          onPeekEnd: () => context.read<GameState>().stopPeek(),
          onFire:    () => context.read<GameState>().fire(),
          onReload:  () => context.read<GameState>().startReload(),
        ),

        // ── 오버레이 (게임 오버 / 클리어 / 정지) ──
        if (state.playState == PlayState.gameOver)
          _GameOverOverlay(state: state),
        if (state.playState == PlayState.stageClear)
          _StageClearOverlay(state: state),
        if (state.playState == PlayState.paused)
          _PauseOverlay(state: state),
      ]),
    );
  }

  Widget _buildBackground(GameState state, bool isPeeking) {
    if (isPeeking) {
      // 내다보기: 야외 배경 (적이 있는 장면)
      return Positioned.fill(
        child: Image.asset(
          'assets/images/stage1_bg.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const _OutdoorFallbackBg(),
        ),
      );
    } else {
      // 엄폐 중: 주인공 뒤에서 보는 어두운 실내 장면
      return const Positioned.fill(child: _IndoorCoverBg());
    }
  }
}

// ══════════════════════════════════════════════════
// 배경 — 실내 엄폐 장면 (내다보기 전)
// ══════════════════════════════════════════════════
class _IndoorCoverBg extends StatelessWidget {
  const _IndoorCoverBg();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _IndoorBgPainter());
  }
}

class _IndoorBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 어두운 실내 바닥/천장
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0A0600), Color(0xFF1A0E08), Color(0xFF0D0700)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 콘크리트 바닥 텍스처
    final floorPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1E1208), Color(0xFF2D1A0A)],
      ).createShader(Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3));
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3),
      floorPaint,
    );

    // 벽 균열 라인
    final crackPaint = Paint()
      ..color = const Color(0xFF3D2010).withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final cracks = [
      [0.55, 0.1, 0.65, 0.35],
      [0.70, 0.2, 0.80, 0.50],
      [0.85, 0.05, 0.90, 0.30],
      [0.60, 0.55, 0.70, 0.70],
      [0.75, 0.60, 0.85, 0.80],
    ];
    for (final c in cracks) {
      canvas.drawLine(
        Offset(size.width * c[0], size.height * c[1]),
        Offset(size.width * c[2], size.height * c[3]),
        crackPaint,
      );
    }

    // 창문 (밖이 보이는 작은 틈 — 빛이 새어 들어옴)
    final lightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.3, -0.5),
        radius: 0.5,
        colors: [
          const Color(0xFFFF6600).withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), lightPaint);

    // 오른쪽 — 벽의 틈/문 (밖으로 통하는 구멍)
    final gapPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          const Color(0xFFFF8800).withValues(alpha: 0.08),
        ],
      ).createShader(Rect.fromLTWH(size.width * 0.5, 0, size.width * 0.5, size.height));
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.5, 0, size.width * 0.5, size.height),
      gapPaint,
    );
  }

  @override
  bool shouldRepaint(_IndoorBgPainter old) => false;
}

// 야외 Fallback 배경 (이미지 없을 때)
class _OutdoorFallbackBg extends StatelessWidget {
  const _OutdoorFallbackBg();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _OutdoorBgPainter());
}

class _OutdoorBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 하늘
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.center,
        colors: [Color(0xFF1A0500), Color(0xFF4A1500), Color(0xFF8B2200)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.6));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.6), sky);

    // 땅
    final ground = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF3D1A00), Color(0xFF1A0D00)],
      ).createShader(Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45));
    canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45), ground);

    // 건물 실루엣
    final ruin = Paint()..color = const Color(0xFF0D0700);
    final buildings = [
      [0.30, 0.30, 0.12, 0.58], [0.45, 0.38, 0.09, 0.58],
      [0.58, 0.25, 0.11, 0.58], [0.72, 0.35, 0.08, 0.58],
      [0.83, 0.28, 0.10, 0.58], [0.92, 0.40, 0.07, 0.58],
    ];
    for (final b in buildings) {
      canvas.drawRect(
        Rect.fromLTWH(size.width * b[0], size.height * b[1],
            size.width * b[2], size.height * (b[3] - b[1])),
        ruin,
      );
    }
  }
  @override
  bool shouldRepaint(_OutdoorBgPainter old) => false;
}

// ══════════════════════════════════════════════════
// 엄폐물 레이어 — 화면 왼쪽 벽 (항상 표시)
// ══════════════════════════════════════════════════
class _CoverLayer extends StatelessWidget {
  final bool        isPeeking;
  final VehicleType vehicle;
  const _CoverLayer({required this.isPeeking, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final size     = MediaQuery.of(context).size;
    final state    = context.watch<GameState>();
    final coverW   = size.width * 0.38;
    // 내다볼 때: 벽이 약간 왼쪽으로 밀려 어깨 정도만 보임
    final peekOffset = isPeeking ? -coverW * 0.20 : 0.0;

    return Positioned(
      left: peekOffset, top: 0, bottom: 0,
      width: coverW,
      child: Stack(children: [
        // 벽 본체
        Positioned.fill(
          child: CustomPaint(
            painter: _WallPainter(vehicle: vehicle),
          ),
        ),
        // 주인공 (벽 안쪽 우측)
        Positioned(
          right: 0,
          bottom: 0,
          child: SizedBox(
            width:  coverW * 0.55,
            height: coverW * 0.90,
            child: _PlayerSprite(isPeeking: isPeeking, peekAmount: state.exposureLevel),
          ),
        ),
      ]),
    );
  }
}

class _WallPainter extends CustomPainter {
  final VehicleType vehicle;
  const _WallPainter({required this.vehicle});

  @override
  void paint(Canvas canvas, Size size) {
    // 콘크리트 벽
    final wall = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [const Color(0xFF3A2418), const Color(0xFF4A3228)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), wall);

    // 균열
    final crack = Paint()
      ..color = const Color(0xFF1E1008)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    for (final c in [
      [0.2, 0.1, 0.5, 0.3], [0.1, 0.4, 0.4, 0.6],
      [0.6, 0.15, 0.8, 0.45], [0.3, 0.65, 0.7, 0.85],
    ]) {
      canvas.drawLine(
        Offset(size.width * c[0], size.height * c[1]),
        Offset(size.width * c[2], size.height * c[3]),
        crack,
      );
    }

    // 오른쪽 그림자 (입체감)
    final shadow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
      ).createShader(Rect.fromLTWH(size.width * 0.5, 0, size.width * 0.5, size.height));
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.5, 0, size.width * 0.5, size.height),
      shadow,
    );

    // 탈것 아이콘
    final icons = ['', '🚗', '🛡️', '🪖', '🚁', '✈️', '🌊'];
    final icon  = icons[vehicle.index.clamp(0, icons.length - 1)];
    if (icon.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(text: icon, style: const TextStyle(fontSize: 28)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width * 0.08, size.height * 0.68));
    }
  }

  @override
  bool shouldRepaint(_WallPainter old) => false;
}

class _PlayerSprite extends StatelessWidget {
  final bool   isPeeking;
  final double peekAmount;
  const _PlayerSprite({required this.isPeeking, required this.peekAmount});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/player.png',
      fit: BoxFit.contain,
      alignment: isPeeking ? Alignment.topRight : Alignment.bottomRight,
      errorBuilder: (_, __, ___) =>
          CustomPaint(painter: _PlayerFallbackPainter(isPeeking: isPeeking)),
    );
  }
}

class _PlayerFallbackPainter extends CustomPainter {
  final bool isPeeking;
  const _PlayerFallbackPainter({required this.isPeeking});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();

    if (isPeeking) {
      // 어깨너머 시점: 상단에 머리+총
      p.color = const Color(0xFF4A3420);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.05, size.height * 0.0,
              size.width * 0.9, size.height * 0.55),
          const Radius.circular(6),
        ),
        p,
      );
      // 머리
      p.color = const Color(0xFFD4AA7D);
      canvas.drawCircle(
          Offset(size.width * 0.45, size.height * 0.15), size.width * 0.22, p);
      // 헬멧
      p.color = const Color(0xFF2D3A2D);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.18, size.height * 0.0,
              size.width * 0.58, size.height * 0.14),
          const Radius.circular(5),
        ),
        p,
      );
      // 총 (오른쪽으로 돌출)
      p.color = const Color(0xFF1A1A1A);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.55, size.height * 0.25,
              size.width * 0.55, size.height * 0.08),
          const Radius.circular(3),
        ),
        p,
      );
    } else {
      // 엄폐 시점: 주인공 뒷모습 (하단에 크게)
      p.color = const Color(0xFF3A2818);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.1, size.height * 0.15,
              size.width * 0.80, size.height * 0.75),
          const Radius.circular(8),
        ),
        p,
      );
      // 머리 (뒷모습)
      p.color = const Color(0xFFBB9977);
      canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.10), size.width * 0.25, p);
      // 헬멧/모자
      p.color = const Color(0xFF2A3020);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.2, size.height * 0.0,
              size.width * 0.60, size.height * 0.12),
          const Radius.circular(6),
        ),
        p,
      );
      // 배낭
      p.color = const Color(0xFF5C3A1A);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.25, size.height * 0.25,
              size.width * 0.50, size.height * 0.45),
          const Radius.circular(5),
        ),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_PlayerFallbackPainter old) => old.isPeeking != isPeeking;
}

// ══════════════════════════════════════════════════
// 적 레이어
// ══════════════════════════════════════════════════
class _EnemiesLayer extends StatelessWidget {
  final GameState state;
  const _EnemiesLayer({required this.state});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: Stack(
        children: state.enemies
            .where((e) => e.isAlive)
            .map((e) => _EnemyWidget(enemy: e, screenSize: size))
            .toList(),
      ),
    );
  }
}

class _EnemyWidget extends StatelessWidget {
  final Enemy enemy;
  final Size  screenSize;
  const _EnemyWidget({required this.enemy, required this.screenSize});

  @override
  Widget build(BuildContext context) {
    final x = enemy.posX * screenSize.width  - 28;
    final y = enemy.posY * screenSize.height - 75;
    return Positioned(
      left: x, top: y,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 인지도 + HP 바
        SizedBox(
          width: 56,
          child: Column(children: [
            if (enemy.alertLevel > 0.05)
              _ThinBar(value: enemy.alertLevel, color: _alertColor(enemy.alertLevel)),
            const SizedBox(height: 2),
            _ThinBar(
              value: enemy.hpRatio,
              color: Color.lerp(Colors.red, Colors.green, enemy.hpRatio)!,
            ),
          ]),
        ),
        const SizedBox(height: 3),
        // 스프라이트
        SizedBox(
          width: 56, height: 70,
          child: Image.asset(
            'assets/images/enemy.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _EnemyFallback(enemy: enemy),
          ),
        ),
        if (enemy.state == EnemyState.alerted)
          const Text('❓', style: TextStyle(fontSize: 14)),
        if (enemy.state == EnemyState.detected)
          const Text('❗', style: TextStyle(fontSize: 16)),
      ]),
    );
  }

  Color _alertColor(double level) {
    if (level < 0.5) return Colors.yellow;
    if (level < 0.8) return Colors.orange;
    return Colors.red;
  }
}

class _ThinBar extends StatelessWidget {
  final double value;
  final Color  color;
  const _ThinBar({required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: Colors.black.withValues(alpha: 0.55),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: color,
          ),
        ),
      ),
    );
  }
}

class _EnemyFallback extends StatelessWidget {
  final Enemy enemy;
  const _EnemyFallback({required this.enemy});
  @override
  Widget build(BuildContext context) {
    final Color c = enemy.type == EnemyType.boss
        ? const Color(0xFF8B0000)
        : enemy.type == EnemyType.veteran
            ? const Color(0xFF4A0080)
            : enemy.type == EnemyType.raider
                ? const Color(0xFF6B3A00)
                : const Color(0xFF3A3A3A);
    return CustomPaint(
        painter: _EnemyFallbackPainter(color: c, state: enemy.state));
  }
}

class _EnemyFallbackPainter extends CustomPainter {
  final Color       color;
  final EnemyState  state;
  const _EnemyFallbackPainter({required this.color, required this.state});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.2, size.height * 0.28,
            size.width * 0.6, size.height * 0.6),
        const Radius.circular(5),
      ),
      p,
    );
    p.color = const Color(0xFFCC9966);
    canvas.drawCircle(
        Offset(size.width * 0.5, size.height * 0.18), size.width * 0.2, p);
    if (state == EnemyState.detected) {
      p.color = Colors.red.withValues(alpha: 0.35);
      canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.5), size.width * 0.4, p);
    }
  }
  @override
  bool shouldRepaint(_EnemyFallbackPainter old) => old.state != state;
}

// ══════════════════════════════════════════════════
// 총알 레이어
// ══════════════════════════════════════════════════
class _BulletsLayer extends StatelessWidget {
  final GameState state;
  const _BulletsLayer({required this.state});
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: CustomPaint(
        painter: _BulletsPainter(bullets: state.bullets, screenSize: size),
      ),
    );
  }
}

class _BulletsPainter extends CustomPainter {
  final List<Bullet> bullets;
  final Size         screenSize;
  const _BulletsPainter({required this.bullets, required this.screenSize});
  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bullets) {
      final x  = b.x * screenSize.width;
      final y  = b.y * screenSize.height;
      final p  = Paint()
        ..color = b.isPlayerBullet
            ? const Color(0xFFFFEE44)
            : const Color(0xFFFF4422)
        ..strokeWidth = b.isPlayerBullet ? 3.5 : 2.5
        ..strokeCap   = StrokeCap.round;
      canvas.drawLine(
        Offset(x - b.dx * 14, y - b.dy * 14),
        Offset(x, y), p,
      );
      final glow = Paint()
        ..color = (b.isPlayerBullet ? Colors.yellow : Colors.red)
            .withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(Offset(x, y), 5, glow);
    }
  }
  @override
  bool shouldRepaint(_BulletsPainter old) => true;
}

// ══════════════════════════════════════════════════
// 4x5 그리드 + 조준선 통합 레이어
// ══════════════════════════════════════════════════
class _GridCrosshairLayer extends StatelessWidget {
  final double aimX;
  final double aimY;
  final bool   hasEnemy;   // 현재 조준 셀에 적이 있는가
  final int    gridCol;    // 조준 중인 열 (0~3)
  final int    gridRow;    // 조준 중인 행 (0~4)

  const _GridCrosshairLayer({
    required this.aimX,
    required this.aimY,
    required this.hasEnemy,
    required this.gridCol,
    required this.gridRow,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _GridCrosshairPainter(
            x:        aimX * size.width,
            y:        aimY * size.height,
            hasEnemy: hasEnemy,
            gridCol:  gridCol,
            gridRow:  gridRow,
            screenW:  size.width,
            screenH:  size.height,
          ),
        ),
      ),
    );
  }
}

class _GridCrosshairPainter extends CustomPainter {
  final double x, y, screenW, screenH;
  final bool   hasEnemy;
  final int    gridCol, gridRow;

  const _GridCrosshairPainter({
    required this.x, required this.y,
    required this.hasEnemy,
    required this.gridCol, required this.gridRow,
    required this.screenW, required this.screenH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = screenW / kGridCols;  // 4열
    final cellH = screenH / kGridRows;  // 5행

    // ── 1. 4x5 그리드 라인 (반투명) ──────────────────
    final gridPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.08)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    // 세로선 (열 경계)
    for (int c = 1; c < kGridCols; c++) {
      final lx = cellW * c;
      canvas.drawLine(Offset(lx, 0), Offset(lx, screenH), gridPaint);
    }
    // 가로선 (행 경계)
    for (int r = 1; r < kGridRows; r++) {
      final ly = cellH * r;
      canvas.drawLine(Offset(0, ly), Offset(screenW, ly), gridPaint);
    }

    // ── 2. 조준 중인 셀 강조 ─────────────────────────
    final cellLeft = gridCol * cellW;
    final cellTop  = gridRow * cellH;
    final cellRect = Rect.fromLTWH(cellLeft, cellTop, cellW, cellH);

    // 셀 배경 하이라이트
    final cellHighlight = Paint()
      ..color = hasEnemy
          ? Colors.red.withValues(alpha: 0.22)      // 적 있음: 붉은 강조
          : Colors.white.withValues(alpha: 0.07);    // 빈 셀: 흰 강조
    canvas.drawRect(cellRect, cellHighlight);

    // 셀 테두리
    final cellBorder = Paint()
      ..color = hasEnemy
          ? Colors.red.withValues(alpha: 0.85)
          : Colors.white.withValues(alpha: 0.40)
      ..strokeWidth = hasEnemy ? 2.2 : 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(cellRect, cellBorder);

    // ── 3. 조준선 십자선 ─────────────────────────────
    // 적 있을 때: 빨간+글로우 / 없을 때: 흰색
    final crossColor = hasEnemy ? Colors.red : Colors.white;
    const r    = 22.0;
    const gap  =  8.0;
    const lineLen = 18.0;

    // 외곽 글로우
    final glow = Paint()
      ..color = crossColor.withValues(alpha: hasEnemy ? 0.35 : 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset(x, y), r + 8, glow);

    // 원
    final circlePaint = Paint()
      ..color = crossColor.withValues(alpha: 0.90)
      ..strokeWidth = hasEnemy ? 2.8 : 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(x, y), r, circlePaint);

    // 십자선
    final linePaint = Paint()
      ..color = crossColor.withValues(alpha: 0.95)
      ..strokeWidth = hasEnemy ? 2.2 : 1.6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(x, y - gap), Offset(x, y - gap - lineLen), linePaint);
    canvas.drawLine(Offset(x, y + gap), Offset(x, y + gap + lineLen), linePaint);
    canvas.drawLine(Offset(x - gap, y), Offset(x - gap - lineLen, y), linePaint);
    canvas.drawLine(Offset(x + gap, y), Offset(x + gap + lineLen, y), linePaint);

    // 중앙 점
    final dotPaint = Paint()
      ..color = crossColor
      ..maskFilter = hasEnemy
          ? const MaskFilter.blur(BlurStyle.normal, 3)
          : null;
    canvas.drawCircle(Offset(x, y), hasEnemy ? 4.5 : 2.5, dotPaint);

    // ── 4. 적 감지 시: "LOCK ON!" 텍스트 ─────────────
    if (hasEnemy) {
      final tp = TextPainter(
        text: const TextSpan(
          text: '🎯 LOCK ON',
          style: TextStyle(
            color: Colors.red,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            shadows: [Shadow(color: Colors.black, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(x - tp.width / 2, y + r + 10),
      );
    }
  }

  @override
  bool shouldRepaint(_GridCrosshairPainter old) =>
      old.x != x || old.y != y ||
      old.hasEnemy != hasEnemy ||
      old.gridCol != gridCol || old.gridRow != gridRow;
}

// ══════════════════════════════════════════════════
// 드래그 조준 오버레이 (센서 없는 환경용)
// ══════════════════════════════════════════════════
class _DragAimOverlay extends StatelessWidget {
  final void Function(Offset) onUpdate;
  const _DragAimOverlay({required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: GestureDetector(
        onPanUpdate: (d) {
          final x = (d.localPosition.dx / size.width).clamp(0.0, 1.0);
          final y = (d.localPosition.dy / size.height).clamp(0.0, 1.0);
          onUpdate(Offset(x, y));
        },
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// HUD
// ══════════════════════════════════════════════════
class _HudLayer extends StatelessWidget {
  final GameState state;
  const _HudLayer({required this.state});

  @override
  Widget build(BuildContext context) {
    final isPeeking = state.cameraMode == CameraMode.peeking;
    return Positioned.fill(
      child: SafeArea(
        child: Stack(children: [
          // 상단 HUD
          Positioned(
            top: 0, left: 0, right: 0,
            child: _TopHud(state: state),
          ),
          // 내다보기 중 — 남은 발수 / 노출 경고
          if (isPeeking)
            Positioned(
              top: 100, left: 20, right: 20,
              child: _PeekingHud(state: state),
            ),
          // 경고 메시지
          if (state.alertMessage != null)
            Positioned(
              top: 95, left: 20, right: 20,
              child: _AlertBanner(message: state.alertMessage!),
            ),
          // 일시정지 버튼
          Positioned(
            top: 8, right: 12,
            child: GestureDetector(
              onTap: () => state.pauseGame(),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.pause, color: Colors.white70, size: 20),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TopHud extends StatelessWidget {
  final GameState state;
  const _TopHud({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5C3A1A).withValues(alpha: 0.6)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: _StatBar(
            label: '❤️ HP',
            value: state.playerHp / state.playerMaxHp,
            color: Color.lerp(Colors.red, Colors.green,
                state.playerHp / state.playerMaxHp)!,
            text: '${state.playerHp}/${state.playerMaxHp}',
          )),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('STAGE ${state.currentStage}',
                style: const TextStyle(
                    color: Color(0xFFFFB347), fontSize: 12,
                    fontWeight: FontWeight.bold, letterSpacing: 1)),
            Text('💰 ${state.stageResources}',
                style: const TextStyle(
                    color: Color(0xFFFFD700), fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 5),
        _StatBar(
          label: '👁 노출',
          value: state.exposureLevel,
          color: Color.lerp(Colors.green, Colors.red, state.exposureLevel)!,
          text: state.exposureLevel < 0.30 ? '안전'
              : state.exposureLevel < 0.60 ? '주의'
              : state.exposureLevel < 0.85 ? '위험!'
              : '발각!',
        ),
      ]),
    );
  }
}

// 내다보기 중 HUD: 남은 발수 + 조준 안내
class _PeekingHud extends StatelessWidget {
  final GameState state;
  const _PeekingHud({required this.state});

  @override
  Widget build(BuildContext context) {
    final w = weaponData[state.currentWeapon]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 무기 / 탄약
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${w.emoji} ${w.name}',
                style: const TextStyle(
                    color: Color(0xFFFFB347), fontSize: 12,
                    fontWeight: FontWeight.bold)),
            Text(state.isReloading
                ? '재장전 중...'
                : '탄창 ${state.currentAmmo} / ${state.reserveAmmo}',
                style: TextStyle(
                    color: state.isReloading ? Colors.yellow : Colors.white60,
                    fontSize: 11)),
          ]),
          // 이번 내다보기 남은 발수
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('남은 기회',
                style: TextStyle(color: Colors.white54, fontSize: 10)),
            Row(children: List.generate(
              state.maxShotsPerPeek,
              (i) => Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  i < state.shotsRemaining ? Icons.circle : Icons.circle_outlined,
                  color: i < state.shotsRemaining ? Colors.red : Colors.grey,
                  size: 14,
                ),
              ),
            )),
          ]),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final double value;
  final Color  color;
  final String text;
  const _StatBar({
    required this.label,
    required this.value,
    required this.color,
    required this.text,
  });
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      const SizedBox(width: 6),
      Expanded(
        child: Stack(children: [
          Container(
            height: 14,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(7),
                boxShadow: [BoxShadow(
                    color: color.withValues(alpha: 0.4), blurRadius: 4)],
              ),
            ),
          ),
          Center(child: Text(text,
              style: const TextStyle(color: Colors.white,
                  fontSize: 9, fontWeight: FontWeight.bold))),
        ]),
      ),
    ]);
  }
}

class _AlertBanner extends StatelessWidget {
  final String message;
  const _AlertBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent),
        boxShadow: [BoxShadow(
            color: Colors.red.withValues(alpha: 0.4), blurRadius: 10)],
      ),
      child: Text(message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white,
              fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
    );
  }
}

// ══════════════════════════════════════════════════
// 효과 레이어
// ══════════════════════════════════════════════════
class _EffectsLayer extends StatelessWidget {
  final GameState state;
  const _EffectsLayer({required this.state});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(children: [
          if (state.playerHitFlash)
            Container(color: Colors.red.withValues(alpha: 0.32)),
          ...state.hitTexts.asMap().entries.map((e) => Positioned(
            left:  size.width  * 0.58 + e.key * 22.0,
            top:   size.height * 0.38 - e.key * 28.0,
            child: Text(
              '-${e.value}',
              style: TextStyle(
                color: e.key == 0 ? Colors.red : Colors.orange,
                fontSize: 18 - e.key * 2.0,
                fontWeight: FontWeight.bold,
                shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
          )),
          if (state.exposureLevel > 0.70)
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Colors.transparent,
                    Colors.red.withValues(
                        alpha: (state.exposureLevel - 0.70) * 0.75),
                  ],
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 컨트롤 버튼 레이어
// ══════════════════════════════════════════════════
class _ControlsLayer extends StatelessWidget {
  final GameState     state;
  final bool          isPeeking;
  final VoidCallback  onPeekStart;
  final VoidCallback  onPeekEnd;
  final VoidCallback  onFire;
  final VoidCallback  onReload;
  const _ControlsLayer({
    required this.state,
    required this.isPeeking,
    required this.onPeekStart,
    required this.onPeekEnd,
    required this.onFire,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: SafeArea(
        top: false,
        child: Container(
          color: Colors.black.withValues(alpha: 0.78),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // 재장전 진행바
            if (state.isReloading)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Column(children: [
                  const Text('🔄 재장전 중...',
                      style: TextStyle(color: Colors.yellow, fontSize: 11)),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: state.reloadProgress,
                    backgroundColor: Colors.grey[800],
                    valueColor:
                        const AlwaysStoppedAnimation(Color(0xFFFFB347)),
                  ),
                ]),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ── 내다보기 버튼 ──────────────
                _HoldButton(
                  label: isPeeking ? '🙈 숨기' : '👁 내다보기',
                  sublabel: isPeeking ? '손 떼면 엄폐' : '누르는 동안 내다봄',
                  color: isPeeking
                      ? const Color(0xFF2A2A00)
                      : const Color(0xFF1A3A1A),
                  borderColor: isPeeking
                      ? const Color(0xFFAAAA00)
                      : const Color(0xFF4A8A4A),
                  width: 145, height: 82,
                  onTapDown: onPeekStart,
                  onTapUp:   onPeekEnd,
                ),

                // ── 재장전 버튼 ─────────────────
                GestureDetector(
                  onTap: onReload,
                  child: Container(
                    width: 62, height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1A1A3A),
                      border: Border.all(
                          color: const Color(0xFF4A4A8A), width: 2),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🔄', style: TextStyle(fontSize: 20)),
                        Text('재장전',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 8)),
                      ],
                    ),
                  ),
                ),

                // ── 사격 버튼 ────────────────────
                _HoldButton(
                  label: '🔫 사격',
                  sublabel: !isPeeking
                      ? '내다보기 후 사격'
                      : state.shotsRemaining > 0
                          ? '기회 ${state.shotsRemaining}발 남음'
                          : '기회 소진!',
                  color: !isPeeking
                      ? const Color(0xFF1A1A1A)
                      : state.shotsRemaining > 0
                          ? const Color(0xFF4A1A1A)
                          : const Color(0xFF2A1A1A),
                  borderColor: !isPeeking
                      ? Colors.grey
                      : state.shotsRemaining > 0
                          ? const Color(0xFFAA3333)
                          : Colors.grey,
                  width: 145, height: 82,
                  onTapDown: onFire,
                  onTapUp:   () {},
                ),
              ],
            ),
            // 안내 텍스트
            const SizedBox(height: 6),
            Text(
              isPeeking
                  ? '폰을 기울여 조준하세요 — 탭으로 사격'
                  : '내다보기로 적 위치 파악 후 정확히 사격하세요',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      ),
    );
  }
}

class _HoldButton extends StatefulWidget {
  final String        label;
  final String        sublabel;
  final Color         color;
  final Color         borderColor;
  final double        width;
  final double        height;
  final VoidCallback  onTapDown;
  final VoidCallback  onTapUp;
  const _HoldButton({
    required this.label, required this.sublabel,
    required this.color, required this.borderColor,
    required this.width, required this.height,
    required this.onTapDown, required this.onTapUp,
  });
  @override
  State<_HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<_HoldButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:        (_) { setState(() => _pressed = true);  widget.onTapDown(); },
      onTapUp:          (_) { setState(() => _pressed = false); widget.onTapUp();   },
      onTapCancel:      ()  { setState(() => _pressed = false); widget.onTapUp();   },
      onLongPressStart: (_) { setState(() => _pressed = true);  widget.onTapDown(); },
      onLongPressEnd:   (_) { setState(() => _pressed = false); widget.onTapUp();   },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: widget.width, height: widget.height,
        decoration: BoxDecoration(
          color: _pressed
              ? widget.color.withValues(alpha: 1.4)
              : widget.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _pressed
                ? widget.borderColor
                : widget.borderColor.withValues(alpha: 0.65),
            width: _pressed ? 2.5 : 1.5,
          ),
          boxShadow: _pressed
              ? [BoxShadow(color: widget.borderColor.withValues(alpha: 0.45),
                    blurRadius: 14, spreadRadius: 2)]
              : [],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(widget.label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(widget.sublabel,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 9)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 오버레이 — 게임 오버 / 스테이지 클리어 / 정지
// ══════════════════════════════════════════════════
class _GameOverOverlay extends StatelessWidget {
  final GameState state;
  const _GameOverOverlay({required this.state});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1A0A00),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withValues(alpha: 0.6), width: 2),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('💀', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 8),
            const Text('전사했다',
                style: TextStyle(color: Color(0xFFFF4422),
                    fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('획득 자원: ${state.stageResources}',
                style: const TextStyle(color: Colors.white60, fontSize: 14)),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _OBtn('다시 시도', const Color(0xFF8B2222),
                  () => state.startStage(state.currentStage)),
              _OBtn('메인 메뉴', const Color(0xFF2A2A2A), () {
                state.returnToMenu();
                Navigator.of(context).pop();
              }),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _StageClearOverlay extends StatelessWidget {
  final GameState state;
  const _StageClearOverlay({required this.state});
  @override
  Widget build(BuildContext context) {
    final hasNext = state.currentStage < 7;
    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1000),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFFFFB347).withValues(alpha: 0.7), width: 2),
            boxShadow: [BoxShadow(
                color: const Color(0xFFFFB347).withValues(alpha: 0.2),
                blurRadius: 20, spreadRadius: 3)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🎖️', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 6),
            Text('STAGE ${state.currentStage} 클리어!',
                style: const TextStyle(color: Color(0xFFFFD700),
                    fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(state.stageConfig.subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(children: [
                _RRow('💰 획득 자원', '${state.stageResources}'),
                _RRow('📦 누적 자원', '${state.totalResources}'),
                if (hasNext) _RRow('🔓 잠금 해제', state.stageConfig.unlockDesc),
              ]),
            ),
            const SizedBox(height: 20),
            if (hasNext)
              _OBtn('STAGE ${state.currentStage + 1} 시작 ▶',
                  const Color(0xFF2A5A2A),
                  () => state.startStage(state.currentStage + 1))
            else
              const Text('🏆 모든 스테이지 클리어!',
                  style: TextStyle(color: Color(0xFFFFD700),
                      fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _OBtn('메인 메뉴', const Color(0xFF2A2A2A), () {
              state.returnToMenu();
              Navigator.of(context).pop();
            }),
          ]),
        ),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  final GameState state;
  const _PauseOverlay({required this.state});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('⏸ 일시정지',
              style: TextStyle(color: Colors.white,
                  fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          _OBtn('계속하기', const Color(0xFF2A4A2A), state.resumeGame),
          const SizedBox(height: 12),
          _OBtn('메인 메뉴', const Color(0xFF2A2A2A), () {
            state.returnToMenu();
            Navigator.of(context).pop();
          }),
        ]),
      ),
    );
  }
}

class _RRow extends StatelessWidget {
  final String l, v;
  const _RRow(this.l, this.v);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text(v, style: const TextStyle(color: Color(0xFFFFD700),
            fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _OBtn extends StatelessWidget {
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  const _OBtn(this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white,
                fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
