/**
 * 设备领域模型
 * 定义 4 类可控设备（灯 / 空调 / 加湿器 / 窗帘）及其可被规则修改的属性。
 */

/** 设备类型 */
export enum DeviceType {
  LIGHT = 'light',
  AC = 'ac',
  HUMIDIFIER = 'humidifier',
  CURTAIN = 'curtain'
}

/** 设备可被规则修改的属性 */
export enum DeviceProperty {
  POWER = 'power',
  BRIGHTNESS = 'brightness',
  TARGET_TEMP = 'targetTemp',
  OPEN_LEVEL = 'openLevel'
}

/** 数值裁剪，用于把越界动作值收敛到设备允许区间 */
export function clamp(value: number, min: number, max: number): number {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}

/**
 * 一台设备的当前状态。
 * 采用宽字段而非继承，便于整体序列化与跨页面传递；
 * 各类设备只使用自己相关的字段（见 DeviceMeta.properties）。
 */
export class DeviceState {
  type: DeviceType = DeviceType.LIGHT;
  name: string = '';
  /** 开关，1 表示开 */
  power: boolean = false;
  /** 灯亮度，0-100 */
  brightness: number = 0;
  /** 空调目标温度，16-30 */
  targetTemp: number = 26;
  /** 窗帘开合度，0-100 */
  openLevel: number = 0;

  constructor(type: DeviceType = DeviceType.LIGHT, name: string = '') {
    this.type = type;
    this.name = name;
  }
}

/**
 * 深拷贝设备状态。
 * 用自由函数而非实例方法：从 Preferences 反序列化出来的对象没有类原型，
 * 调用实例方法会失败，所以所有操作一律走自由函数。
 */
export function cloneDevice(source: DeviceState): DeviceState {
  const copy: DeviceState = new DeviceState(source.type, source.name);
  copy.power = source.power;
  copy.brightness = source.brightness;
  copy.targetTemp = source.targetTemp;
  copy.openLevel = source.openLevel;
  return copy;
}

/** 以数值形式读取设备属性，布尔属性用 1/0 表示，便于统一比较与记录 */
export function readDeviceProperty(device: DeviceState, property: DeviceProperty): number {
  switch (property) {
    case DeviceProperty.POWER:
      return device.power ? 1 : 0;
    case DeviceProperty.BRIGHTNESS:
      return device.brightness;
    case DeviceProperty.TARGET_TEMP:
      return device.targetTemp;
    case DeviceProperty.OPEN_LEVEL:
      return device.openLevel;
    default:
      return 0;
  }
}

/** 写入设备属性，自动裁剪到合法区间 */
export function writeDeviceProperty(device: DeviceState, property: DeviceProperty, value: number): void {
  switch (property) {
    case DeviceProperty.POWER:
      device.power = value > 0;
      break;
    case DeviceProperty.BRIGHTNESS:
      device.brightness = clamp(Math.round(value), 0, 100);
      break;
    case DeviceProperty.TARGET_TEMP:
      device.targetTemp = clamp(Math.round(value), 16, 30);
      break;
    case DeviceProperty.OPEN_LEVEL:
      device.openLevel = clamp(Math.round(value), 0, 100);
      break;
    default:
      break;
  }
}

/** 设备展示元数据，供界面渲染编辑项使用 */
export class DeviceMeta {
  type: DeviceType = DeviceType.LIGHT;
  label: string = '';
  properties: DeviceProperty[] = [];

  constructor(type: DeviceType, label: string, properties: DeviceProperty[]) {
    this.type = type;
    this.label = label;
    this.properties = properties;
  }
}

const DEVICE_METAS: DeviceMeta[] = [
  new DeviceMeta(DeviceType.LIGHT, '照明灯', [DeviceProperty.POWER, DeviceProperty.BRIGHTNESS]),
  new DeviceMeta(DeviceType.AC, '空调', [DeviceProperty.POWER, DeviceProperty.TARGET_TEMP]),
  new DeviceMeta(DeviceType.HUMIDIFIER, '加湿器', [DeviceProperty.POWER]),
  new DeviceMeta(DeviceType.CURTAIN, '窗帘', [DeviceProperty.OPEN_LEVEL])
];

/** 获取全部设备元数据 */
export function getDeviceMetas(): DeviceMeta[] {
  return DEVICE_METAS;
}

/** 按类型取设备元数据 */
export function getDeviceMeta(type: DeviceType): DeviceMeta {
  for (let i = 0; i < DEVICE_METAS.length; i++) {
    if (DEVICE_METAS[i].type === type) {
      return DEVICE_METAS[i];
    }
  }
  return DEVICE_METAS[0];
}

/** 设备中文名 */
export function deviceLabel(type: DeviceType): string {
  return getDeviceMeta(type).label;
}

/** 属性中文名 */
export function propertyLabel(property: DeviceProperty): string {
  switch (property) {
    case DeviceProperty.POWER:
      return '开关';
    case DeviceProperty.BRIGHTNESS:
      return '亮度';
    case DeviceProperty.TARGET_TEMP:
      return '目标温度';
    case DeviceProperty.OPEN_LEVEL:
      return '开合度';
    default:
      return '';
  }
}

/** 属性单位 */
export function propertyUnit(property: DeviceProperty): string {
  switch (property) {
    case DeviceProperty.BRIGHTNESS:
    case DeviceProperty.OPEN_LEVEL:
      return '%';
    case DeviceProperty.TARGET_TEMP:
      return '℃';
    default:
      return '';
  }
}

/** 属性值的可读形式，布尔属性显示为「开 / 关」 */
export function formatPropertyValue(property: DeviceProperty, value: number): string {
  if (property === DeviceProperty.POWER) {
    return value > 0 ? '开' : '关';
  }
  return `${Math.round(value)}${propertyUnit(property)}`;
}

/** 生成一套默认设备（首次启动时使用） */
export function createDefaultDevices(): DeviceState[] {
  const list: DeviceState[] = [];
  const light: DeviceState = new DeviceState(DeviceType.LIGHT, '主灯');
  light.power = false;
  light.brightness = 80;
  const ac: DeviceState = new DeviceState(DeviceType.AC, '空调');
  ac.power = false;
  ac.targetTemp = 26;
  const humidifier: DeviceState = new DeviceState(DeviceType.HUMIDIFIER, '加湿器');
  humidifier.power = false;
  const curtain: DeviceState = new DeviceState(DeviceType.CURTAIN, '窗帘');
  curtain.openLevel = 0;
  list.push(light);
  list.push(ac);
  list.push(humidifier);
  list.push(curtain);
  return list;
}

/** 在设备列表中按类型查找 */
export function findDevice(devices: DeviceState[], type: DeviceType): DeviceState {
  for (let i = 0; i < devices.length; i++) {
    if (devices[i].type === type) {
      return devices[i];
    }
  }
  return new DeviceState(type, deviceLabel(type));
}
