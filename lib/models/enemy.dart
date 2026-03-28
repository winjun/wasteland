import 'dart:math';

enum EnemyState { patrolling, alerted, detected, dead }
enum EnemyType  { scavenger, raider, veteran, boss }

class Enemy {
  final String    id;
  final EnemyType type;
  final String    name;
  final String    emoji;

  // 위치 (0~1 정규화)
  double posX;
  double posY;

  // 체력
  int maxHp;
  int currentHp;

  // 상태
  EnemyState state;
  double alertLevel;
  double alertDecayRate;

  // 이동 — 사방 이동용
  double speed;       // 기본 이동 속도
  double patrolDx;    // 현재 X 방향 속도
  double patrolDy;    // 현재 Y 방향 속도 (사방 이동)
  double patrolMinX;
  double patrolMaxX;

  // 방향 변경 타이머
  double dirChangeTimer;
  double dirChangeInterval;

  // 사격
  int    damage;
  double fireRate;
  double lastFireTime;

  Enemy({
    required this.id,
    required this.type,
    required this.name,
    required this.emoji,
    required this.posX,
    required this.posY,
    required this.maxHp,
    required this.damage,
    required this.fireRate,
    required this.patrolMinX,
    required this.patrolMaxX,
    this.alertDecayRate  = 0.15,
    this.speed           = 0.04,
  })  : currentHp       = maxHp,
        state            = EnemyState.patrolling,
        alertLevel       = 0.0,
        lastFireTime     = 0.0,
        dirChangeTimer   = 0.0,
        dirChangeInterval = 2.0 + Random().nextDouble() * 2.0,
        patrolDx         = (Random().nextBool() ? 1 : -1) * 0.04,
        patrolDy         = (Random().nextDouble() - 0.5) * 0.06;

  bool   get isAlive => currentHp > 0;
  double get hpRatio => currentHp / maxHp;

  void takeDamage(int dmg) {
    currentHp = max(0, currentHp - dmg);
    if (currentHp <= 0) state = EnemyState.dead;
  }

  // ── 팩토리 ──────────────────────────────────
  static Enemy createScavenger(String id, double x, double minX, double maxX) =>
      Enemy(
        id: id, type: EnemyType.scavenger,
        name: '약탈자', emoji: '💀',
        posX: x, posY: 0.5 + Random().nextDouble() * 0.3,
        maxHp: 60,  damage: 15, fireRate: 1.0,
        patrolMinX: minX, patrolMaxX: maxX,
        alertDecayRate: 0.12, speed: 0.04,
      );

  static Enemy createRaider(String id, double x, double minX, double maxX) =>
      Enemy(
        id: id, type: EnemyType.raider,
        name: '레이더', emoji: '⚔️',
        posX: x, posY: 0.4 + Random().nextDouble() * 0.3,
        maxHp: 120, damage: 25, fireRate: 1.5,
        patrolMinX: minX, patrolMaxX: maxX,
        alertDecayRate: 0.08, speed: 0.055,
      );

  static Enemy createVeteran(String id, double x, double minX, double maxX) =>
      Enemy(
        id: id, type: EnemyType.veteran,
        name: '베테랑', emoji: '🔱',
        posX: x, posY: 0.35 + Random().nextDouble() * 0.35,
        maxHp: 200, damage: 40, fireRate: 2.0,
        patrolMinX: minX, patrolMaxX: maxX,
        alertDecayRate: 0.05, speed: 0.035,
      );

  static Enemy createBoss(String id) =>
      Enemy(
        id: id, type: EnemyType.boss,
        name: '전쟁 군주', emoji: '👑',
        posX: 0.72, posY: 0.45,
        maxHp: 800, damage: 60, fireRate: 2.5,
        patrolMinX: 0.50, patrolMaxX: 0.92,
        alertDecayRate: 0.02, speed: 0.025,
      );
}
