/**
 * 界面文案格式化。
 */

import { deviceLabel, DeviceState, DeviceType, formatPropertyValue } from '../model/DeviceModel';
import { AutomationRule } from '../model/RuleModel';

/** 规则动作摘要：「空调→开，照明灯→70%」 */
export function actionSummary(rule: AutomationRule): string {
  const parts: string[] = [];
  for (let i = 0; i < rule.actions.length; i++) {
    const action = rule.actions[i];
    parts.push(`${deviceLabel(action.device)} → ${formatPropertyValue(action.property, action.value)}`);
  }
  return parts.join('，');
}

/** 设备当前状态的一句话描述 */
export function deviceStatusText(device: DeviceState): string {
  switch (device.type) {
    case DeviceType.LIGHT:
      return device.power ? `开 · 亮度 ${device.brightness}%` : '关';
    case DeviceType.AC:
      return device.power ? `开 · 目标 ${device.targetTemp}℃` : '关';
    case DeviceType.HUMIDIFIER:
      return device.power ? '运行中' : '关';
    case DeviceType.CURTAIN:
      return device.openLevel > 0 ? `开启 ${device.openLevel}%` : '已闭合';
    default:
      return '';
  }
}

/** 设备是否处于「工作」状态，用于卡片高亮 */
export function isDeviceActive(device: DeviceState): boolean {
  switch (device.type) {
    case DeviceType.CURTAIN:
      return device.openLevel > 0;
    default:
      return device.power;
  }
}
