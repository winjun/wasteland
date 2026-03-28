import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/game_state.dart';
import '../models/stage_config.dart';
import '../models/weapon.dart';
import 'game_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with TickerProviderStateMixin {
  late AnimationController _titleController;
  late AnimationController _bgController;
  late Animation<double> _titlePulse;
  late Animation<double> _bgParallax;

  @override
  void initState() {
    super.initState();
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _titlePulse = Tween<double>(begin: 0.9, end: 1.05).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeInOut),
    );

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _bgParallax = Tween<double>(begin: 0, end: 1).animate(_bgController);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // 배경
        _AnimatedBackground(animation: _bgParallax),
        // 어두운 그라디언트 오버레이
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xAA000000),
                Color(0x55000000),
                Color(0xCC000000),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // 먼지/파티클 효과
        const _DustParticles(),
        // 메인 콘텐츠
        SafeArea(
          child: Column(children: [
            const Spacer(flex: 2),
            // 타이틀
            ScaleTransition(
              scale: _titlePulse,
              child: const _GameTitle(),
            ),
            const SizedBox(height: 8),
            // 세계관 설명
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '인류 마지막 대전 이후, 황폐해진 지구.\n남은 자원을 차지하기 위해 생존자들이 싸운다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFBB9977),
                  fontSize: 12,
                  height: 1.6,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Spacer(flex: 1),
            // 진행 상황 카드
            _ProgressCard(state: state),
            const Spacer(flex: 1),
            // 메인 버튼들
            _MainButtons(state: state),
            const Spacer(flex: 2),
            // 하단 정보
            _BottomInfo(state: state),
            const SizedBox(height: 16),
          ]),
        ),
      ]),
    );
  }
}

// ── 배경 애니메이션 ──────────────────────────────
class _AnimatedBackground extends StatelessWidget {
  final Animation<double> animation;
  const _AnimatedBackground({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        return Positioned.fill(
          child: Image.asset(
            'assets/images/wasteland_bg.jpg',
            fit: BoxFit.cover,
            alignment: Alignment(animation.value * 0.2 - 0.1, 0),
            errorBuilder: (_, __, ___) => _FallbackBackground(t: animation.value),
          ),
        );
      },
    );
  }
}

class _FallbackBackground extends StatelessWidget {
  final double t;
  const _FallbackBackground({required this.t});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _WastelandPainter(t: t));
  }
}

class _WastelandPainter extends CustomPainter {
  final double t;
  const _WastelandPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    // 하늘 - 붉은 노을
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: const [Color(0xFF1A0500), Color(0xFF4A1500), Color(0xFF8B2200)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.65));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.65), skyPaint);

    // 땅 - 잿빛 황무지
    final groundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFF3D1A00), Color(0xFF1A0D00)],
      ).createShader(Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4));
    canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4), groundPaint);

    // 태양 (붉은)
    final sunPaint = Paint()
      ..color = const Color(0xFFFF4400)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(
        Offset(size.width * 0.7, size.height * 0.35), 45, sunPaint);
    sunPaint.maskFilter = null;
    sunPaint.color = const Color(0xFFFF6622);
    canvas.drawCircle(
        Offset(size.width * 0.7, size.height * 0.35), 22, sunPaint);

    // 무너진 건물 실루엣
    _drawRuins(canvas, size);
  }

  void _drawRuins(Canvas canvas, Size size) {
    final rp = Paint()..color = const Color(0xFF0D0700);
    final buildings = [
      [0.05, 0.4, 0.12, 0.65],
      [0.15, 0.5, 0.08, 0.65],
      [0.22, 0.38, 0.10, 0.65],
      [0.35, 0.52, 0.07, 0.65],
      [0.60, 0.42, 0.09, 0.65],
      [0.72, 0.35, 0.11, 0.65],
      [0.85, 0.48, 0.08, 0.65],
      [0.92, 0.40, 0.07, 0.65],
    ];
    for (final b in buildings) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * b[0],
          size.height * b[1],
          size.width * b[2],
          size.height * (b[3] - b[1]),
        ),
        rp,
      );
    }
  }

  @override
  bool shouldRepaint(_WastelandPainter old) => old.t != t;
}

// ── 먼지 파티클 ──────────────────────────────────
class _DustParticles extends StatefulWidget {
  const _DustParticles();

  @override
  State<_DustParticles> createState() => _DustParticlesState();
}

class _DustParticlesState extends State<_DustParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_Particle> _particles = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 25; i++) {
      _particles.add(_Particle.random(_rng));
    }
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(() {
        setState(() {
          for (final p in _particles) {
            p.update(0.016);
            if (p.y < 0) p.reset(_rng);
          }
        });
      })
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _ParticlePainter(particles: _particles),
        ),
      ),
    );
  }
}

class _Particle {
  double x, y, size, speed, opacity;
  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });

  factory _Particle.random(Random rng) => _Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: rng.nextDouble() * 3 + 1,
        speed: rng.nextDouble() * 0.003 + 0.001,
        opacity: rng.nextDouble() * 0.5 + 0.1,
      );

  void update(double dt) {
    y -= speed;
    x += (speed * 0.3);
  }

  void reset(Random rng) {
    y = 1.0;
    x = rng.nextDouble();
    size = rng.nextDouble() * 3 + 1;
    speed = rng.nextDouble() * 0.003 + 0.001;
    opacity = rng.nextDouble() * 0.5 + 0.1;
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  const _ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = Color.fromARGB(
          (p.opacity * 255).round(),
          200, 160, 100,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

// ── 게임 타이틀 ──────────────────────────────────
class _GameTitle extends StatelessWidget {
  const _GameTitle();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // 부제목
      const Text(
        'POST-APOCALYPSE TACTICAL SHOOTER',
        style: TextStyle(
          color: Color(0xFF8B6A3A),
          fontSize: 10,
          letterSpacing: 3,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      // 메인 타이틀
      ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE066), Color(0xFFFF8800), Color(0xFFCC3300)],
        ).createShader(bounds),
        child: const Text(
          'WASTELAND\nWARRIORS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 44,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            height: 1.1,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 8, offset: Offset(3, 3)),
              Shadow(color: Color(0xFFFF4400), blurRadius: 20),
            ],
          ),
        ),
      ),
      const SizedBox(height: 4),
      // 장식 라인
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 60,
          height: 1.5,
          color: const Color(0xFF8B4400),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('☠', style: TextStyle(color: Color(0xFFAA5500), fontSize: 16)),
        ),
        Container(
          width: 60,
          height: 1.5,
          color: const Color(0xFF8B4400),
        ),
      ]),
    ]);
  }
}

// ── 진행 상황 카드 ───────────────────────────────
class _ProgressCard extends StatelessWidget {
  final GameState state;
  const _ProgressCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6B3A1A).withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFAA5500).withValues(alpha: 0.15),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem('🎖', 'STAGE', '${state.currentStage} / 7'),
          _VertDivider(),
          _StatItem('💰', '자원', '${state.totalResources}'),
          _VertDivider(),
          _StatItem('🏆', '최고 자원', '${state.highScore}'),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  const _StatItem(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(icon, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 2),
      Text(label,
          style: const TextStyle(color: Color(0xFF8B6A3A), fontSize: 9, letterSpacing: 1)),
      const SizedBox(height: 2),
      Text(value,
          style: const TextStyle(
            color: Color(0xFFFFD080),
            fontSize: 15,
            fontWeight: FontWeight.bold,
          )),
    ]);
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      color: const Color(0xFF6B3A1A).withValues(alpha: 0.5),
    );
  }
}

// ── 메인 버튼 ────────────────────────────────────
class _MainButtons extends StatelessWidget {
  final GameState state;
  const _MainButtons({required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(children: [
        // 게임 시작 버튼 (가장 크게)
        _GlowButton(
          label: '▶  게임 시작',
          sublabel: stageConfigs[(state.currentStage - 1).clamp(0, stageConfigs.length - 1)].subtitle,
          color: const Color(0xFF7A2200),
          glowColor: const Color(0xFFFF4400),
          height: 72,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GameScreen()),
            );
            context.read<GameState>().startStage(state.currentStage);
          },
        ),
        const SizedBox(height: 12),
        // 스테이지 선택 / 무기고 행
        Row(children: [
          Expanded(
            child: _GlowButton(
              label: '🗺  스테이지',
              sublabel: '선택',
              color: const Color(0xFF1A3A1A),
              glowColor: const Color(0xFF44AA44),
              height: 54,
              onTap: () => _showStageSelect(context, state),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _GlowButton(
              label: '🔫  무기고',
              sublabel: '보유 무기 확인',
              color: const Color(0xFF1A1A3A),
              glowColor: const Color(0xFF4444AA),
              height: 54,
              onTap: () => _showArsenal(context, state),
            ),
          ),
        ]),
      ]),
    );
  }

  void _showStageSelect(BuildContext context, GameState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StageSelectSheet(state: state),
    );
  }

  void _showArsenal(BuildContext context, GameState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ArsenalSheet(state: state),
    );
  }
}

class _GlowButton extends StatefulWidget {
  final String label;
  final String sublabel;
  final Color color;
  final Color glowColor;
  final double height;
  final VoidCallback onTap;

  const _GlowButton({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.glowColor,
    required this.height,
    required this.onTap,
  });

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: widget.height,
        decoration: BoxDecoration(
          color: _pressed
              ? widget.color.withValues(alpha: 1.2)
              : widget.color.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _pressed
                ? widget.glowColor.withValues(alpha: 0.9)
                : widget.glowColor.withValues(alpha: 0.45),
            width: _pressed ? 2 : 1.5,
          ),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: widget.glowColor.withValues(alpha: 0.4),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: widget.glowColor.withValues(alpha: 0.15),
                    blurRadius: 8,
                  ),
                ],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(
            widget.label,
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.height > 60 ? 18 : 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            widget.sublabel,
            style: TextStyle(
              color: Colors.white54,
              fontSize: widget.height > 60 ? 11 : 10,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── 스테이지 선택 시트 ───────────────────────────
class _StageSelectSheet extends StatelessWidget {
  final GameState state;
  const _StageSelectSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0700),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0xFF6B3A1A), width: 1.5)),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF6B3A1A),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        const Text('🗺  스테이지 선택',
            style: TextStyle(
              color: Color(0xFFFFD080),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            )),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: stageConfigs.length,
            itemBuilder: (_, i) {
              final cfg = stageConfigs[i];
              final isUnlocked = cfg.stageNumber <= state.currentStage;
              final isCurrent = cfg.stageNumber == state.currentStage;
              return _StageTile(
                config: cfg,
                isUnlocked: isUnlocked,
                isCurrent: isCurrent,
                onTap: isUnlocked
                    ? () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const GameScreen()),
                        );
                        state.startStage(cfg.stageNumber);
                      }
                    : null,
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }
}

class _StageTile extends StatelessWidget {
  final StageConfig config;
  final bool isUnlocked;
  final bool isCurrent;
  final VoidCallback? onTap;

  const _StageTile({
    required this.config,
    required this.isUnlocked,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vehicleIcons = ['', '🚗', '🛡️', '🪖', '🚁', '✈️', '🌊'];
    final vehicleIcon = vehicleIcons[config.vehicle.index.clamp(0, vehicleIcons.length - 1)];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCurrent
              ? const Color(0xFF3A1A00).withValues(alpha: 0.8)
              : isUnlocked
                  ? const Color(0xFF1A0D00).withValues(alpha: 0.8)
                  : const Color(0xFF0D0700).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent
                ? const Color(0xFFFF8800)
                : isUnlocked
                    ? const Color(0xFF6B3A1A)
                    : Colors.grey.withValues(alpha: 0.3),
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Row(children: [
          // 스테이지 번호
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrent
                  ? const Color(0xFFFF8800).withValues(alpha: 0.3)
                  : isUnlocked
                      ? const Color(0xFF3A1A00)
                      : Colors.grey.withValues(alpha: 0.1),
              border: Border.all(
                color: isCurrent
                    ? const Color(0xFFFF8800)
                    : isUnlocked
                        ? const Color(0xFF8B5A2A)
                        : Colors.grey.withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: Text(
                '${config.stageNumber}',
                style: TextStyle(
                  color: isUnlocked ? const Color(0xFFFFD080) : Colors.grey,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 설명
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(
                  config.title,
                  style: TextStyle(
                    color: isUnlocked ? Colors.white : Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (vehicleIcon.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(vehicleIcon, style: const TextStyle(fontSize: 14)),
                ],
              ]),
              Text(
                config.subtitle,
                style: TextStyle(
                  color: isUnlocked ? const Color(0xFFAA8860) : Colors.grey.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ]),
          ),
          // 잠금/해제 아이콘
          if (!isUnlocked)
            const Icon(Icons.lock, color: Colors.grey, size: 20)
          else if (isCurrent)
            const Text('▶', style: TextStyle(color: Color(0xFFFF8800), fontSize: 18))
          else
            const Icon(Icons.check_circle, color: Color(0xFF44AA44), size: 20),
        ]),
      ),
    );
  }
}

// ── 무기고 시트 ──────────────────────────────────
class _ArsenalSheet extends StatelessWidget {
  final GameState state;
  const _ArsenalSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0700),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0xFF1A3A6B), width: 1.5)),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF3A4A8B),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        const Text('🔫  무기고',
            style: TextStyle(
              color: Color(0xFF80B0FF),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            )),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            '자원을 획득하면 더 강력한 무기가 잠금 해제됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _buildWeaponList(state),
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  List<Widget> _buildWeaponList(GameState state) {
    final weaponOrder = <WeaponType>[
      WeaponType.fists,
      WeaponType.pipe,
      WeaponType.pistol,
      WeaponType.shotgun,
      WeaponType.rifle,
      WeaponType.smg,
      WeaponType.sniperRifle,
      WeaponType.rpg,
      WeaponType.minigun,
      WeaponType.nuke,
    ];

    return weaponOrder.map((type) {
      final data = weaponData[type];
      if (data == null) return const SizedBox.shrink();
      final isUnlocked = state.unlockedWeapons.contains(type);

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUnlocked
              ? const Color(0xFF1A1A3A).withValues(alpha: 0.8)
              : const Color(0xFF0D0D0D).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isUnlocked
                ? const Color(0xFF3A3A8B).withValues(alpha: 0.7)
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Row(children: [
          Text(data.emoji,
              style: TextStyle(
                fontSize: 24,
                color: isUnlocked ? Colors.white : Colors.grey.withValues(alpha: 0.4),
              )),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                data.name,
                style: TextStyle(
                  color: isUnlocked ? Colors.white : Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '공격력 ${data.damage}  |  탄창 ${data.magazineSize}발  |  연사 ${data.fireRate}/s',
                style: TextStyle(
                  color: isUnlocked
                      ? const Color(0xFF8898CC)
                      : Colors.grey.withValues(alpha: 0.4),
                  fontSize: 10,
                ),
              ),
            ]),
          ),
          if (!isUnlocked)
            const Icon(Icons.lock, color: Colors.grey, size: 18)
          else
            const Icon(Icons.check_circle, color: Color(0xFF44AA88), size: 18),
        ]),
      );
    }).toList();
  }
}

// ── 하단 정보 ────────────────────────────────────
class _BottomInfo extends StatelessWidget {
  final GameState state;
  const _BottomInfo({required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('💀 ',
              style: TextStyle(fontSize: 12, color: Colors.white38)),
          Text(
            '포스트 아포칼립스 · 7스테이지 · 탈출구 없음',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
