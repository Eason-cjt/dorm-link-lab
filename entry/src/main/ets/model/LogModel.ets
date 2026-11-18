/**
 * 规则执行记录模型
 * 一次模拟演练产出一份 ExecutionResult，完整保留：环境快照、规则执行顺序、
 * 设备变化明细、冲突裁决结果、被跳过的规则及原因。
 */

import { DeviceProperty, DeviceState, DeviceType } from './DeviceModel';
import { EnvData } from './EnvModel';

/** 一条被触发的规则，order 表示它在本次演练中的执行顺序 */
export class RuleHit {
  ruleId: string = '';
  ruleName: string = '';
  priority: number = 0;
  /** 执行顺序，1 表示最先执行 */
  order: number = 0;
  /** 命中的条件描述，用于说明"为什么触发" */
  conditionSummary: string = '';
}

/** 一次设备属性的变化 */
export class DeviceChange {
  deviceType: DeviceType = DeviceType.LIGHT;
  deviceName: string = '';
  property: DeviceProperty = DeviceProperty.POWER;
  fromValue: number = 0;
  toValue: number = 0;
  ruleId: string = '';
  ruleName: string = '';
}

/** 一次冲突裁决：两条规则对同一设备同一属性给出不同目标值时产生 */
export class ConflictRecord {
  deviceType: DeviceType = DeviceType.LIGHT;
  deviceName: string = '';
  property: DeviceProperty = DeviceProperty.POWER;
  winnerRuleId: string = '';
  winnerRuleName: string = '';
  winnerValue: number = 0;
  loserRuleId: string = '';
  loserRuleName: string = '';
  loserValue: number = 0;
  /** 裁决依据的文字说明 */
  reason: string = '';
}

/** 被跳过（未执行）的规则 */
export class SkippedRule {
  ruleId: string = '';
  ruleName: string = '';
  reason: string = '';
}

/** 一次完整演练的结果 */
export class ExecutionResult {
  id: string = '';
  /** 时间戳，毫秒 */
  timestamp: number = 0;
  /** 场景名，手工调参时为空 */
  scenarioName: string = '';
  env: EnvData = new EnvData();
  hits: RuleHit[] = [];
  changes: DeviceChange[] = [];
  conflicts: ConflictRecord[] = [];
  skipped: SkippedRule[] = [];
  /** 演练结束后的设备快照 */
  devicesAfter: DeviceState[] = [];
}
