// 무기 시스템 — 소총부터 핵까지
enum WeaponType {
  fists,       // 맨손 (stage 0 — 시작)
  pipe,        // 쇠파이프
  pistol,      // 권총
  rifle,       // 소총
  shotgun,     // 샷건
  smg,         // 기관단총
  sniperRifle, // 저격소총
  rpg,         // RPG
  flamethrower,// 화염방사기
  minigun,     // 미니건
  nuke,        // 핵무기급
}

// 탈것
enum VehicleType {
  none,       // 도보
  car,        // 자동차
  armoredCar, // 장갑차
  tank,       // 탱크
  helicopter, // 헬리콥터
  jet,        // 전투기
  submarine,  // 잠수함
}

class Weapon {
  final WeaponType type;
  final String name;
  final String emoji;
  final int damage;
  final double fireRate;      // 초당 발사 횟수
  final int magazineSize;
  final double reloadTime;    // 재장전 시간(초)
  final double spread;        // 탄 퍼짐 (0=정확, 1=넓음)
  final bool isAutomatic;
  final String description;
  final int unlockStage;

  const Weapon({
    required this.type,
    required this.name,
    required this.emoji,
    required this.damage,
    required this.fireRate,
    required this.magazineSize,
    required this.reloadTime,
    required this.spread,
    required this.isAutomatic,
    required this.description,
    required this.unlockStage,
  });
}

const Map<WeaponType, Weapon> weaponData = {
  WeaponType.fists: Weapon(
    type: WeaponType.fists,
    name: '맨손',
    emoji: '👊',
    damage: 5,
    fireRate: 0.5,
    magazineSize: 999,
    reloadTime: 0,
    spread: 0,
    isAutomatic: false,
    description: '아무것도 없다. 주먹뿐.',
    unlockStage: 1,
  ),
  WeaponType.pipe: Weapon(
    type: WeaponType.pipe,
    name: '쇠파이프',
    emoji: '🔧',
    damage: 15,
    fireRate: 0.8,
    magazineSize: 999,
    reloadTime: 0,
    spread: 0,
    isAutomatic: false,
    description: '폐허에서 주운 쇠파이프. 생각보다 잘 날아간다.',
    unlockStage: 1,
  ),
  WeaponType.pistol: Weapon(
    type: WeaponType.pistol,
    name: '권총',
    emoji: '🔫',
    damage: 25,
    fireRate: 1.5,
    magazineSize: 8,
    reloadTime: 1.5,
    spread: 0.1,
    isAutomatic: false,
    description: '9mm 권총. 오래됐지만 아직 쓸만하다.',
    unlockStage: 1,
  ),
  WeaponType.rifle: Weapon(
    type: WeaponType.rifle,
    name: '돌격소총',
    emoji: '🪖',
    damage: 35,
    fireRate: 3.0,
    magazineSize: 30,
    reloadTime: 2.0,
    spread: 0.15,
    isAutomatic: true,
    description: '구형 AK. 황무지에서 가장 많이 보이는 총.',
    unlockStage: 2,
  ),
  WeaponType.shotgun: Weapon(
    type: WeaponType.shotgun,
    name: '샷건',
    emoji: '💥',
    damage: 80,
    fireRate: 0.8,
    magazineSize: 6,
    reloadTime: 2.5,
    spread: 0.4,
    isAutomatic: false,
    description: '근거리에서 무시무시한 위력. 산탄이 넓게 퍼진다.',
    unlockStage: 2,
  ),
  WeaponType.sniperRifle: Weapon(
    type: WeaponType.sniperRifle,
    name: '저격소총',
    emoji: '🎯',
    damage: 150,
    fireRate: 0.4,
    magazineSize: 5,
    reloadTime: 3.0,
    spread: 0.0,
    isAutomatic: false,
    description: '원거리 한 방. 노출 최소화에 최적.',
    unlockStage: 3,
  ),
  WeaponType.smg: Weapon(
    type: WeaponType.smg,
    name: '기관단총',
    emoji: '⚡',
    damage: 20,
    fireRate: 8.0,
    magazineSize: 45,
    reloadTime: 1.8,
    spread: 0.25,
    isAutomatic: true,
    description: '연사력 최강. 탄약 소모가 빠르다.',
    unlockStage: 3,
  ),
  WeaponType.rpg: Weapon(
    type: WeaponType.rpg,
    name: 'RPG',
    emoji: '🚀',
    damage: 500,
    fireRate: 0.2,
    magazineSize: 1,
    reloadTime: 4.0,
    spread: 0.0,
    isAutomatic: false,
    description: '탱크도 날려버린다. 폭발 범위에 주의.',
    unlockStage: 4,
  ),
  WeaponType.minigun: Weapon(
    type: WeaponType.minigun,
    name: '미니건',
    emoji: '🌀',
    damage: 15,
    fireRate: 15.0,
    magazineSize: 200,
    reloadTime: 5.0,
    spread: 0.3,
    isAutomatic: true,
    description: '모든 것을 갈아버린다. 탱크 위에서 최강.',
    unlockStage: 5,
  ),
  WeaponType.nuke: Weapon(
    type: WeaponType.nuke,
    name: '전술 핵',
    emoji: '☢️',
    damage: 9999,
    fireRate: 0.05,
    magazineSize: 1,
    reloadTime: 10.0,
    spread: 0.0,
    isAutomatic: false,
    description: '황무지를 더 황무지로. 최후의 수단.',
    unlockStage: 7,
  ),
};
