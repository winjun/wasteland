import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/enemy.dart';
import '../models/weapon.dart';
import '../models/stage_config.dart';
import '../audio/sound_manager.dart';

// ── 카메라 모드 ──────────────────────────────────
enum CameraMode {
  cover,   // 숨음: 주인공 뒤에서 보는 시점
  peeking, // 내다보기: 어깨너머 조준 시점
}

enum PlayState { menu, playing, paused, stageClear, gameOver }

// ── 총알 ────────────────────────────────────────
class Bullet {
  double x, y;   // 0.0~1.0 정규화 좌표
  double dx, dy; // 방향 벡터 (정규화)
  int damage;
  bool isPlayerBullet;
  bool active;

  Bullet({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.damage,
    required this.isPlayerBullet,
  }) : active = true;
}

// ── 그리드 상수 ──────────────────────────────────
const int kGridCols = 4;
const int kGridRows = 5;

// ── 조준 정보 ────────────────────────────────────
class AimData {
  /// 화면 내 조준점 위치 (0.0~1.0)
  double x;
  double y;

  /// 현재 조준 그리드 셀 (col, row) — 0-indexed
  int gridCol = kGridCols ~/ 2;
  int gridRow = kGridRows ~/ 2;

  /// 조준 그리드 안에 적이 있는가 (빨간 조준선 표시용)
  bool hasEnemyInCell = false;

  AimData({this.x = 0.5, this.y = 0.5});

  void updateGrid() {
    gridCol = (x * kGridCols).floor().clamp(0, kGridCols - 1);
    gridRow = (y * kGridRows).floor().clamp(0, kGridRows - 1);
  }
}

// ── GameState ────────────────────────────────────
class GameState extends ChangeNotifier {
  // 게임 진행
  PlayState playState = PlayState.menu;
  int currentStage   = 1;
  int totalResources = 0;
  int stageResources = 0;
  int highScore      = 0;

  // 카메라
  CameraMode cameraMode = CameraMode.cover;

  // 플레이어
  int playerMaxHp    = 100;
  int playerHp       = 100;
  double exposureLevel = 0.0;   // 누적 노출 (0~1)
  bool isReloading   = false;
  double reloadProgress = 0.0;
  int currentAmmo    = 8;
  int maxAmmo        = 8;
  int reserveAmmo    = 64;

  // 사격 기회 시스템
  /// 현재 내다보기 세션에서 남은 발수
  int shotsRemaining  = 0;
  /// 무기별 한 번 내다볼 때 주어지는 최대 발수
  int maxShotsPerPeek = 1;

  // 무기 / 탈것
  WeaponType  currentWeapon  = WeaponType.pistol;
  VehicleType currentVehicle = VehicleType.none;
  List<WeaponType> unlockedWeapons =
      [WeaponType.fists, WeaponType.pipe, WeaponType.pistol];

  // 적 / 총알
  List<Enemy>  enemies = [];
  List<Bullet> bullets = [];

  // 조준
  AimData aimData = AimData();

  // 효과
  bool   playerHitFlash      = false;
  bool   screenShake         = false;
  double screenShakeIntensity = 0.0;
  List<int> hitTexts         = [];
  String? alertMessage;
  double  alertTimer         = 0.0;

  // 내부 타이머
  Timer?  _gameLoop;
  double  _elapsed      = 0.0;
  double  _lastFireTime = 0.0;
  double  _fireInterval = 1.0;
  final Random _rng     = Random();

  GameState() { _loadProgress(); }

  // ── 저장 / 불러오기 ──────────────────────────
  Future<void> _loadProgress() async {
    final p = await SharedPreferences.getInstance();
    totalResources = p.getInt('ww_resources') ?? 0;
    highScore      = p.getInt('ww_highScore')  ?? 0;
    currentStage   = p.getInt('ww_stage')      ?? 1;
    final saved    = p.getStringList('ww_weapons') ?? ['pistol'];
    unlockedWeapons = saved.map((w) => WeaponType.values.firstWhere(
        (e) => e.name == w, orElse: () => WeaponType.pistol)).toList();
    notifyListeners();
  }

  Future<void> _saveProgress() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('ww_resources', totalResources);
    await p.setInt('ww_highScore', highScore);
    await p.setInt('ww_stage',     currentStage);
    await p.setStringList('ww_weapons', unlockedWeapons.map((w) => w.name).toList());
  }

  // ── 스테이지 설정 게터 ───────────────────────
  StageConfig get stageConfig =>
      stageConfigs[(currentStage - 1).clamp(0, stageConfigs.length - 1)];

  // ── 게임 시작 ────────────────────────────────
  void startStage(int stage) {
    SoundManager.instance.stopAll();
    currentStage = stage.clamp(1, stageConfigs.length);
    final cfg    = stageConfig;

    playerMaxHp        = cfg.playerMaxHp;
    playerHp           = playerMaxHp;
    exposureLevel      = 0.0;
    isReloading        = false;
    reloadProgress     = 0.0;
    stageResources     = 0;
    screenShake        = false;
    screenShakeIntensity = 0.0;
    hitTexts.clear();
    playerHitFlash     = false;
    alertMessage       = null;
    alertTimer         = 0.0;
    bullets.clear();
    cameraMode         = CameraMode.cover;
    shotsRemaining     = 0;
    aimData            = AimData();

    currentVehicle = cfg.vehicle;
    final available = cfg.availableWeapons
        .where((w) => unlockedWeapons.contains(w)).toList();
    currentWeapon = available.isNotEmpty ? available.last : WeaponType.fists;
    _updateAmmoForWeapon();

    _spawnEnemies(cfg);
    playState = PlayState.playing;
    _startGameLoop();
    // 게임 시작 시 엄폐 상태 → 숨소리 재생
    SoundManager.instance.startBreathing();
    notifyListeners();
  }

  void _updateAmmoForWeapon() {
    final w        = weaponData[currentWeapon]!;
    maxAmmo        = w.magazineSize;
    currentAmmo    = w.magazineSize;
    reserveAmmo    = w.magazineSize * 4;
    _fireInterval  = 1.0 / w.fireRate;
    // 내다보기 한 번에 줄 발수: 샷건·RPG·저격은 1발, 자동화기는 3발, 나머지 2발
    maxShotsPerPeek = _calcShotsPerPeek(currentWeapon);
  }

  int _calcShotsPerPeek(WeaponType t) {
    switch (t) {
      case WeaponType.sniperRifle:
      case WeaponType.rpg:
      case WeaponType.shotgun:
      case WeaponType.nuke:
        return 1;
      case WeaponType.smg:
      case WeaponType.minigun:
        return 5;
      case WeaponType.rifle:
        return 3;
      default:
        return 2;
    }
  }

  // ── 적 생성 ──────────────────────────────────
  void _spawnEnemies(StageConfig cfg) {
    enemies.clear();
    // 적은 화면 오른쪽 절반(0.5~0.95)에서 사방 이동
    for (int i = 0; i < cfg.enemyCount.clamp(1, 12); i++) {
      final baseX = 0.55 + _rng.nextDouble() * 0.35; // 0.55~0.90
      final baseY = 0.25 + _rng.nextDouble() * 0.55; // 0.25~0.80
      Enemy e;
      if (cfg.hasBoss && i == cfg.enemyCount - 1) {
        e = Enemy.createBoss('boss_$i');
        e.posX = 0.72; e.posY = 0.5;
      } else if (i % 3 == 2 && cfg.stageNumber >= 3) {
        e = Enemy.createVeteran('vet_$i', baseX,
            (baseX - 0.15).clamp(0.45, 0.65),
            (baseX + 0.15).clamp(0.55, 0.95));
        e.posY = baseY;
      } else if (i % 2 == 1 && cfg.stageNumber >= 2) {
        e = Enemy.createRaider('raid_$i', baseX,
            (baseX - 0.15).clamp(0.45, 0.65),
            (baseX + 0.15).clamp(0.55, 0.95));
        e.posY = baseY;
      } else {
        e = Enemy.createScavenger('scav_$i', baseX,
            (baseX - 0.12).clamp(0.45, 0.65),
            (baseX + 0.12).clamp(0.55, 0.95));
        e.posY = baseY;
      }
      // 사방 이동 초기 방향 랜덤
      e.patrolDy = (_rng.nextDouble() - 0.5) * 0.2;
      enemies.add(e);
    }
  }

  // ── 게임 루프 ────────────────────────────────
  void _startGameLoop() {
    _gameLoop?.cancel();
    _elapsed = 0;
    _gameLoop = Timer.periodic(
        const Duration(milliseconds: 33), (_) => _tick(0.033));
  }

  void _tick(double dt) {
    if (playState != PlayState.playing) return;
    _elapsed += dt;
    _updateEnemies(dt);
    _updateBullets(dt);
    _updateEffects(dt);
    _checkExposureDecay(dt);
    _checkWinCondition();
    notifyListeners();
  }

  // ── 노출도 (숨을 때만 감소) ──────────────────
  void _checkExposureDecay(double dt) {
    if (cameraMode == CameraMode.cover) {
      exposureLevel = max(0.0, exposureLevel - dt * 0.25);
    }
  }

  // ── 적 AI (사방 이동) ───────────────────────
  void _updateEnemies(double dt) {
    for (final e in enemies) {
      if (!e.isAlive) continue;

      // 사방 이동: X + Y
      e.posX += e.patrolDx * dt;
      e.posY += e.patrolDy * dt;

      // X 경계 반사
      if (e.posX <= e.patrolMinX || e.posX >= e.patrolMaxX) {
        e.patrolDx = -e.patrolDx;
        e.posX = e.posX.clamp(e.patrolMinX, e.patrolMaxX);
        // Y 방향도 약간 랜덤하게 바꿈
        e.patrolDy = (_rng.nextDouble() - 0.5) * e.speed * 1.5;
      }

      // Y 경계 반사 (화면 세로 0.15~0.90 범위)
      if (e.posY <= 0.15 || e.posY >= 0.90) {
        e.patrolDy = -e.patrolDy;
        e.posY = e.posY.clamp(0.15, 0.90);
        e.patrolDx = (_rng.nextDouble() - 0.5) * e.speed * 2.0;
        if (e.patrolDx.abs() < 0.02) e.patrolDx = e.speed;
      }

      // 일정 간격으로 방향 살짝 변경 (자연스러운 이동)
      e.dirChangeTimer += dt;
      if (e.dirChangeTimer > e.dirChangeInterval) {
        e.dirChangeTimer = 0;
        e.dirChangeInterval = 1.5 + _rng.nextDouble() * 2.0;
        e.patrolDy += (_rng.nextDouble() - 0.5) * 0.1;
        e.patrolDy = e.patrolDy.clamp(-e.speed * 1.5, e.speed * 1.5);
      }

      // 노출도 기반 인지 시스템 (내다볼 때만)
      if (cameraMode == CameraMode.peeking) {
        final dist = (1.0 - e.posX).clamp(0.3, 1.0);
        e.alertLevel = min(1.0,
            e.alertLevel + dt * exposureLevel * dist * 0.5);
      } else {
        e.alertLevel = max(0.0, e.alertLevel - dt * e.alertDecayRate);
      }

      // 상태 전환
      if (e.alertLevel >= 1.0) {
        if (e.state != EnemyState.detected) {
          e.state = EnemyState.detected;
          _showAlert('⚠️ 발각됐다!');
        }
      } else if (e.alertLevel >= 0.5) {
        if (e.state == EnemyState.patrolling) {
          e.state = EnemyState.alerted;
          _showAlert('👁 적이 수상해하고 있다...');
        }
      } else {
        if (e.state == EnemyState.alerted) e.state = EnemyState.patrolling;
      }

      // 발각된 적: 내다보는 중에만 반격
      if (e.state == EnemyState.detected &&
          cameraMode == CameraMode.peeking) {
        e.lastFireTime += dt;
        if (e.lastFireTime >= 1.0 / e.fireRate) {
          e.lastFireTime = 0;
          _enemyFire(e);
        }
      }
    }
  }

  void _enemyFire(Enemy e) {
    final spread = (_rng.nextDouble() - 0.5) * 0.06;
    bullets.add(Bullet(
      x: e.posX - 0.04,
      y: e.posY + spread,
      dx: -0.65,
      dy: spread * 2,
      damage: e.damage,
      isPlayerBullet: false,
    ));
  }

  // ── 총알 업데이트 ───────────────────────────
  void _updateBullets(double dt) {
    for (final b in bullets) {
      if (!b.active) continue;
      b.x += b.dx * dt;
      b.y += b.dy * dt;

      if (b.x < -0.05 || b.x > 1.05 || b.y < -0.05 || b.y > 1.05) {
        b.active = false;
        continue;
      }

      if (b.isPlayerBullet) {
        // 그리드 기반 히트 판정: 총알과 적이 같은 그리드 셀이면 명중
        final bc = (b.x * kGridCols).floor().clamp(0, kGridCols - 1);
        final br = (b.y * kGridRows).floor().clamp(0, kGridRows - 1);
        for (final e in enemies) {
          if (!e.isAlive) continue;
          final ec = (e.posX * kGridCols).floor().clamp(0, kGridCols - 1);
          final er = (e.posY * kGridRows).floor().clamp(0, kGridRows - 1);
          // 그리드 셀 일치 OR 정밀 거리 판정 (둘 다 통과하면 명중)
          final gridHit = (bc == ec && br == er);
          final distHit = (b.x - e.posX).abs() < 0.08 && (b.y - e.posY).abs() < 0.10;
          if (gridHit || distHit) {
            b.active = false;
            final dmg = (b.damage * (0.8 + _rng.nextDouble() * 0.4)).round();
            e.takeDamage(dmg);
            hitTexts.add(dmg);
            if (!e.isAlive) {
              stageResources += _resourceByType(e.type);
              SoundManager.instance.playEnemyDie();
            }
            break;
          }
        }
      } else {
        // 적 총알: 내다보는 중에만 맞음
        if (cameraMode == CameraMode.peeking && b.x < 0.12) {
          b.active = false;
          _playerTakeDamage(b.damage);
        }
      }
    }
    bullets.removeWhere((b) => !b.active);
    hitTexts = hitTexts.take(5).toList();
  }

  int _resourceByType(EnemyType t) {
    switch (t) {
      case EnemyType.scavenger: return 20;
      case EnemyType.raider:    return 40;
      case EnemyType.veteran:   return 80;
      case EnemyType.boss:      return 300;
    }
  }

  void _playerTakeDamage(int dmg) {
    playerHp = max(0, playerHp - dmg);
    playerHitFlash       = true;
    screenShake          = true;
    screenShakeIntensity = 8.0;
    SoundManager.instance.playPlayerHit();
    if (playerHp <= 0) {
      SoundManager.instance.stopAll();
      playState = PlayState.gameOver;
      _gameLoop?.cancel();
    }
  }

  // ── 효과 업데이트 ───────────────────────────
  void _updateEffects(double dt) {
    if (screenShakeIntensity > 0) {
      screenShakeIntensity = max(0, screenShakeIntensity - dt * 30);
      if (screenShakeIntensity <= 0) screenShake = false;
    }
    playerHitFlash = false;
    if (alertTimer > 0) {
      alertTimer = max(0, alertTimer - dt);
      if (alertTimer <= 0) alertMessage = null;
    }
  }

  void _showAlert(String msg) {
    alertMessage = msg;
    alertTimer   = 2.5;
  }

  // ── 승리 조건 ───────────────────────────────
  void _checkWinCondition() {
    if (enemies.every((e) => !e.isAlive)) {
      final reward   = stageConfig.resourceReward + stageResources;
      totalResources += reward;
      stageResources  = reward;
      if (totalResources > highScore) highScore = totalResources;
      _unlockNextStage();
      _saveProgress();
      playState = PlayState.stageClear;
      _gameLoop?.cancel();
    }
  }

  void _unlockNextStage() {
    final next = currentStage + 1;
    if (next <= stageConfigs.length) {
      for (final w in stageConfigs[next - 1].availableWeapons) {
        if (!unlockedWeapons.contains(w)) unlockedWeapons.add(w);
      }
    }
  }

  // ── 플레이어 액션 ───────────────────────────

  /// 내다보기 시작 — 조준 세션 개시
  void startPeek() {
    if (playState != PlayState.playing) return;
    if (cameraMode == CameraMode.peeking) return;
    cameraMode      = CameraMode.peeking;
    shotsRemaining  = maxShotsPerPeek;
    exposureLevel   = min(1.0, exposureLevel + 0.08);
    // 숨소리 중지 + 총 준비 소리
    SoundManager.instance.stopBreathing();
    SoundManager.instance.playGunReady();
    notifyListeners();
  }

  /// 내다보기 종료 — 엄폐로 복귀
  void stopPeek() {
    if (cameraMode == CameraMode.cover) return;
    cameraMode     = CameraMode.cover;
    shotsRemaining = 0;
    // 엄폐 복귀 시 숨소리 재개
    SoundManager.instance.startBreathing();
    notifyListeners();
  }

  /// 자이로 조준값 업데이트 (센서에서 매 프레임 호출)
  void updateAim(double x, double y) {
    aimData.x = x.clamp(0.0, 1.0);
    aimData.y = y.clamp(0.0, 1.0);
    aimData.updateGrid();
    // 그리드 셀 안에 살아있는 적이 있는지 체크
    aimData.hasEnemyInCell = enemies.any((e) {
      if (!e.isAlive) return false;
      final ec = (e.posX * kGridCols).floor().clamp(0, kGridCols - 1);
      final er = (e.posY * kGridRows).floor().clamp(0, kGridRows - 1);
      return ec == aimData.gridCol && er == aimData.gridRow;
    });
  }

  /// 사격 — 내다보기 중이고 남은 발수가 있을 때만
  void fire() {
    if (playState != PlayState.playing)        return;
    if (cameraMode != CameraMode.peeking)      return;
    if (shotsRemaining <= 0)                   return;
    if (isReloading)                           return;
    if (currentAmmo <= 0) { startReload(); return; }

    final now = _elapsed;
    if (now - _lastFireTime < _fireInterval)   return;
    _lastFireTime = now;

    final w = weaponData[currentWeapon]!;
    currentAmmo--;
    shotsRemaining--;
    // 무기별 발사음
    SoundManager.instance.playGunShot(currentWeapon.name);

    // 조준점에서 총알 발사 (aimData.x, aimData.y 방향)
    final pellets = currentWeapon == WeaponType.shotgun ? 5 : 1;
    for (int i = 0; i < pellets; i++) {
      final spread = (_rng.nextDouble() - 0.5) * w.spread;
      // 총알 출발점: 화면 왼쪽 (플레이어 총구)
      const startX = 0.10;
      const startY = 0.50;
      // 조준점으로 향하는 방향 벡터
      final tx = aimData.x - startX;
      final ty = aimData.y - startY;
      final len = sqrt(tx * tx + ty * ty);
      final nx  = len > 0 ? tx / len : 1.0;
      final ny  = len > 0 ? ty / len : 0.0;
      bullets.add(Bullet(
        x: startX, y: startY,
        dx: nx * 3.5 + spread,  // 총알 속도 대폭 향상 (0.9 → 3.5)
        dy: ny * 3.5 + spread,
        damage: w.damage,
        isPlayerBullet: true,
      ));
    }

    // 노출 증가 (사격 시 적이 더 쉽게 인지)
    exposureLevel = min(1.0, exposureLevel + 0.20);

    // 샷 소진 시 자동으로 엄폐 복귀
    if (shotsRemaining <= 0) {
      Future.delayed(const Duration(milliseconds: 150), stopPeek);
    }

    if (currentAmmo <= 0) startReload();
    notifyListeners();
  }

  /// 재장전
  void startReload() {
    if (isReloading)             return;
    if (reserveAmmo <= 0)        return;
    if (currentAmmo >= maxAmmo)  return;
    isReloading    = true;
    reloadProgress = 0.0;
    SoundManager.instance.playReload();
    final reloadDur = weaponData[currentWeapon]!.reloadTime;
    Timer.periodic(const Duration(milliseconds: 50), (t) {
      reloadProgress += 0.05 / reloadDur;
      if (reloadProgress >= 1.0) {
        final need = maxAmmo - currentAmmo;
        final fill = min(need, reserveAmmo);
        currentAmmo   += fill;
        reserveAmmo   -= fill;
        isReloading    = false;
        reloadProgress = 0.0;
        t.cancel();
        notifyListeners();
      }
    });
  }

  void switchWeapon(WeaponType t) {
    if (!unlockedWeapons.contains(t))              return;
    if (!stageConfig.availableWeapons.contains(t)) return;
    currentWeapon = t;
    _updateAmmoForWeapon();
    notifyListeners();
  }

  void pauseGame() {
    SoundManager.instance.stopAll();
    playState = PlayState.paused;
    _gameLoop?.cancel();
    notifyListeners();
  }

  void resumeGame() {
    playState = PlayState.playing;
    _startGameLoop();
    // 재개 시 카메라 모드에 따라 사운드 복구
    if (cameraMode == CameraMode.cover) {
      SoundManager.instance.startBreathing();
    }
    notifyListeners();
  }

  void returnToMenu() {
    _gameLoop?.cancel();
    SoundManager.instance.stopAll();
    playState  = PlayState.menu;
    cameraMode = CameraMode.cover;
    notifyListeners();
  }

  @override
  void dispose() {
    _gameLoop?.cancel();
    SoundManager.instance.stopAll();
    super.dispose();
  }
}
