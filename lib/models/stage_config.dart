import 'weapon.dart';

// 스테이지별 설정
class StageConfig {
  final int stageNumber;
  final String title;
  final String subtitle;
  final String backgroundDesc;
  final List<WeaponType> availableWeapons;
  final VehicleType vehicle;
  final int enemyCount;
  final bool hasBoss;
  final int resourceReward;   // 클리어 보상 자원
  final String unlockDesc;    // 다음 스테이지 잠금 해제 설명
  final double coverWidth;    // 엄폐물 너비 (0.0~1.0)
  final int playerMaxHp;

  const StageConfig({
    required this.stageNumber,
    required this.title,
    required this.subtitle,
    required this.backgroundDesc,
    required this.availableWeapons,
    required this.vehicle,
    required this.enemyCount,
    required this.hasBoss,
    required this.resourceReward,
    required this.unlockDesc,
    required this.coverWidth,
    required this.playerMaxHp,
  });
}

const List<StageConfig> stageConfigs = [
  StageConfig(
    stageNumber: 1,
    title: 'STAGE 1',
    subtitle: '폐허의 시작',
    backgroundDesc: '무너진 콘크리트 건물 안. 맨손과 주운 권총이 전부.',
    availableWeapons: [WeaponType.fists, WeaponType.pipe, WeaponType.pistol],
    vehicle: VehicleType.none,
    enemyCount: 3,
    hasBoss: false,
    resourceReward: 100,
    unlockDesc: '권총 획득 → Stage 2',
    coverWidth: 0.42,
    playerMaxHp: 100,
  ),
  StageConfig(
    stageNumber: 2,
    title: 'STAGE 2',
    subtitle: '폐허의 거리',
    backgroundDesc: '잿더미가 된 도심 도로. 소총과 샷건을 손에 넣었다.',
    availableWeapons: [WeaponType.pistol, WeaponType.rifle, WeaponType.shotgun],
    vehicle: VehicleType.none,
    enemyCount: 5,
    hasBoss: false,
    resourceReward: 200,
    unlockDesc: '자동차 획득 → Stage 3',
    coverWidth: 0.38,
    playerMaxHp: 120,
  ),
  StageConfig(
    stageNumber: 3,
    title: 'STAGE 3',
    subtitle: '차량 전투',
    backgroundDesc: '자동차를 얻었다. 이동하며 싸운다.',
    availableWeapons: [WeaponType.rifle, WeaponType.shotgun, WeaponType.smg, WeaponType.sniperRifle],
    vehicle: VehicleType.car,
    enemyCount: 6,
    hasBoss: true,
    resourceReward: 350,
    unlockDesc: '장갑차 획득 → Stage 4',
    coverWidth: 0.35,
    playerMaxHp: 180,
  ),
  StageConfig(
    stageNumber: 4,
    title: 'STAGE 4',
    subtitle: '강철의 요새',
    backgroundDesc: '장갑차에 탑승. RPG를 확보했다.',
    availableWeapons: [WeaponType.sniperRifle, WeaponType.smg, WeaponType.rpg],
    vehicle: VehicleType.armoredCar,
    enemyCount: 8,
    hasBoss: true,
    resourceReward: 500,
    unlockDesc: '탱크 획득 → Stage 5',
    coverWidth: 0.32,
    playerMaxHp: 250,
  ),
  StageConfig(
    stageNumber: 5,
    title: 'STAGE 5',
    subtitle: '탱크 대전',
    backgroundDesc: '탱크를 손에 넣었다. 미니건이 불을 뿜는다.',
    availableWeapons: [WeaponType.rpg, WeaponType.minigun],
    vehicle: VehicleType.tank,
    enemyCount: 10,
    hasBoss: true,
    resourceReward: 750,
    unlockDesc: '헬리콥터 획득 → Stage 6',
    coverWidth: 0.30,
    playerMaxHp: 400,
  ),
  StageConfig(
    stageNumber: 6,
    title: 'STAGE 6',
    subtitle: '하늘의 지배자',
    backgroundDesc: '헬리콥터로 하늘을 장악한다.',
    availableWeapons: [WeaponType.minigun, WeaponType.rpg],
    vehicle: VehicleType.helicopter,
    enemyCount: 12,
    hasBoss: true,
    resourceReward: 1000,
    unlockDesc: '전투기 획득 → Stage 7',
    coverWidth: 0.28,
    playerMaxHp: 500,
  ),
  StageConfig(
    stageNumber: 7,
    title: 'STAGE 7',
    subtitle: '최후의 전쟁',
    backgroundDesc: '전투기와 잠수함. 그리고 전술 핵.',
    availableWeapons: [WeaponType.minigun, WeaponType.rpg, WeaponType.nuke],
    vehicle: VehicleType.jet,
    enemyCount: 15,
    hasBoss: true,
    resourceReward: 2000,
    unlockDesc: '최종 클리어!',
    coverWidth: 0.25,
    playerMaxHp: 700,
  ),
];
