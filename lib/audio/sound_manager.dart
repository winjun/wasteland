import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// 게임 전체 사운드를 관리하는 싱글턴
/// - Android: audioplayers 패키지 사용
/// - Web: kIsWeb 감지 후 동일 패키지 (web 지원) 사용
class SoundManager {
  SoundManager._();
  static final SoundManager instance = SoundManager._();

  bool _enabled = true;
  bool get enabled => _enabled;

  // ── 1회성 효과음용 풀 ────────────────────────
  // 총소리는 연속 발사 때 겹쳐 들려야 하므로 작은 풀을 씀
  final List<AudioPlayer> _sfxPool = [];
  static const int _poolSize = 6;

  // ── 루프 전용 플레이어 ───────────────────────
  AudioPlayer? _breathingPlayer; // 숨소리 (엄폐 중 루프)

  bool _initialized = false;

  // ── 초기화 ───────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // SFX 풀 미리 생성
    for (int i = 0; i < _poolSize; i++) {
      final p = AudioPlayer();
      await p.setReleaseMode(ReleaseMode.stop);
      _sfxPool.add(p);
    }

    // 숨소리 전용 플레이어
    _breathingPlayer = AudioPlayer();
    await _breathingPlayer!.setReleaseMode(ReleaseMode.loop);
    await _breathingPlayer!.setVolume(0.55);
  }

  // ── 효과음 재생 ──────────────────────────────
  Future<void> _playSfx(String assetPath, {double volume = 1.0}) async {
    if (!_enabled) return;
    try {
      // 풀에서 사용 가능한 플레이어 찾기 (정지 상태)
      AudioPlayer? player;
      for (final p in _sfxPool) {
        if (p.state == PlayerState.stopped ||
            p.state == PlayerState.completed) {
          player = p;
          break;
        }
      }
      // 모두 사용 중이면 첫 번째를 강제로 씀
      player ??= _sfxPool.first;

      await player.setVolume(volume);
      await player.play(AssetSource(assetPath));
    } catch (e) {
      if (kDebugMode) debugPrint('[Sound] _playSfx error: $e');
    }
  }

  // ── 공개 API ─────────────────────────────────

  /// 무기 타입별 발사음
  Future<void> playGunShot(String weaponType) async {
    switch (weaponType) {
      case 'pistol':
      case 'fists':
      case 'pipe':
        await _playSfx('sounds/pistol_shot.mp3', volume: 0.85);
      case 'shotgun':
        await _playSfx('sounds/shotgun_shot.mp3', volume: 1.0);
      case 'sniperRifle':
        await _playSfx('sounds/sniper_shot.mp3', volume: 0.95);
      case 'rifle':
      case 'smg':
      case 'minigun':
        await _playSfx('sounds/rifle_shot.mp3', volume: 0.90);
      case 'rpg':
      case 'nuke':
        await _playSfx('sounds/shotgun_shot.mp3', volume: 1.0);
      default:
        await _playSfx('sounds/pistol_shot.mp3', volume: 0.85);
    }
  }

  /// 내다볼 때 총 준비 "철컥" 소리
  Future<void> playGunReady() async {
    await _playSfx('sounds/gun_ready.mp3', volume: 0.80);
  }

  /// 재장전 "철컥" 소리
  Future<void> playReload() async {
    await _playSfx('sounds/gun_reload.mp3', volume: 0.85);
  }

  /// 플레이어 피격음
  Future<void> playPlayerHit() async {
    await _playSfx('sounds/player_hit.mp3', volume: 1.0);
  }

  /// 적 사망음
  Future<void> playEnemyDie() async {
    await _playSfx('sounds/enemy_die.mp3', volume: 0.75);
  }

  /// 숨소리 시작 (엄폐 중)
  Future<void> startBreathing() async {
    if (!_enabled) return;
    try {
      if (_breathingPlayer == null) return;
      if (_breathingPlayer!.state == PlayerState.playing) return;
      await _breathingPlayer!.play(AssetSource('sounds/breathing_tense.mp3'));
    } catch (e) {
      if (kDebugMode) debugPrint('[Sound] startBreathing error: $e');
    }
  }

  /// 숨소리 중지 (내다보기 / 게임오버 시)
  Future<void> stopBreathing() async {
    try {
      await _breathingPlayer?.stop();
    } catch (_) {}
  }

  /// 모든 사운드 중지
  Future<void> stopAll() async {
    await stopBreathing();
    for (final p in _sfxPool) {
      try { await p.stop(); } catch (_) {}
    }
  }

  /// 사운드 켜기/끄기 토글
  Future<void> toggle() async {
    _enabled = !_enabled;
    if (!_enabled) await stopAll();
  }

  Future<void> dispose() async {
    await stopAll();
    await _breathingPlayer?.dispose();
    for (final p in _sfxPool) {
      await p.dispose();
    }
  }
}
