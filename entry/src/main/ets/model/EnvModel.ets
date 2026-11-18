/**
 * 模拟环境数据模型
 * 提供 4 项可调整的环境输入，其中 3 项为连续数值、1 项为布尔状态。
 */

/** 环境字段 */
export enum EnvField {
  TEMPERATURE = 'temperature',
  HUMIDITY = 'humidity',
  ILLUMINANCE = 'illuminance',
  OCCUPANCY = 'occupancy'
}

/** 比较运算符 */
export enum CompareOp {
  GT = '>',
  GTE = '>=',
  LT = '<',
  LTE = '<=',
  EQ = '==',
  NE = '!='
}

/** 一次模拟环境的快照 */
export class EnvData {
  /** 温度，℃ */
  temperature: number = 26;
  /** 相对湿度，% */
  humidity: number = 50;
  /** 光照度，lux */
  illuminance: number = 300;
  /** 宿舍是否有人 */
  occupancy: boolean = true;
}

/** 深拷贝环境快照（自由函数，反序列化对象同样适用） */
export function cloneEnv(source: EnvData): EnvData {
  const copy: EnvData = new EnvData();
  copy.temperature = source.temperature;
  copy.humidity = source.humidity;
  copy.illuminance = source.illuminance;
  copy.occupancy = source.occupancy;
  return copy;
}

/** 以数值形式读取环境字段，布尔字段用 1/0，便于统一参与比较 */
export function readEnvField(env: EnvData, field: EnvField): number {
  switch (field) {
    case EnvField.TEMPERATURE:
      return env.temperature;
    case EnvField.HUMIDITY:
      return env.humidity;
    case EnvField.ILLUMINANCE:
      return env.illuminance;
    case EnvField.OCCUPANCY:
      return env.occupancy ? 1 : 0;
    default:
      return 0;
  }
}

/** 字段中文名 */
export function envFieldLabel(field: EnvField): string {
  switch (field) {
    case EnvField.TEMPERATURE:
      return '温度';
    case EnvField.HUMIDITY:
      return '湿度';
    case EnvField.ILLUMINANCE:
      return '光照';
    case EnvField.OCCUPANCY:
      return '是否有人';
    default:
      return '';
  }
}

/** 字段单位 */
export function envFieldUnit(field: EnvField): string {
  switch (field) {
    case EnvField.TEMPERATURE:
      return '℃';
    case EnvField.HUMIDITY:
      return '%';
    case EnvField.ILLUMINANCE:
      return 'lux';
    default:
      return '';
  }
}

/** 字段取值下限 */
export function envFieldMin(field: EnvField): number {
  switch (field) {
    case EnvField.TEMPERATURE:
      return 10;
    case EnvField.HUMIDITY:
      return 10;
    case EnvField.ILLUMINANCE:
      return 0;
    default:
      return 0;
  }
}

/** 字段取值上限 */
export function envFieldMax(field: EnvField): number {
  switch (field) {
    case EnvField.TEMPERATURE:
      return 40;
    case EnvField.HUMIDITY:
      return 95;
    case EnvField.ILLUMINANCE:
      return 2000;
    default:
      return 1;
  }
}

/** 是否为布尔型字段 */
export function isBooleanField(field: EnvField): boolean {
  return field === EnvField.OCCUPANCY;
}

/** 环境值的中文表述 */
export function formatEnvValue(field: EnvField, value: number): string {
  if (field === EnvField.OCCUPANCY) {
    return value > 0 ? '有人' : '无人';
  }
  return `${Math.round(value)}${envFieldUnit(field)}`;
}
