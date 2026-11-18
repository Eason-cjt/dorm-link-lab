/**
 * 预置数据：默认规则与模拟场景
 *
 * 首次启动灌入 6 条规则，覆盖：
 *  - 单条件触发（高温开空调、干燥加湿、夜间闭帘）
 *  - 多动作联动（无人断电同时关灯和空调）
 *  - 双条件与逻辑（阴天且有人才补光）
 *  - 优先级冲突（「节能关空调」与「高温开空调」争抢同一属性）
 */

import { DeviceProperty, DeviceType } from '../model/DeviceModel';
import { CompareOp, EnvData, EnvField } from '../model/EnvModel';
import { AutomationRule, LogicOp, RuleAction, RuleCondition } from '../model/RuleModel';

/** 一个可一键套用的模拟场景 */
export class ScenarioPreset {
  name: string = '';
  description: string = '';
  env: EnvData = new EnvData();

  constructor(name: string, description: string, env: EnvData) {
    this.name = name;
    this.description = description;
    this.env = env;
  }
}

function makeEnv(temperature: number, humidity: number, illuminance: number, occupancy: boolean): EnvData {
  const env: EnvData = new EnvData();
  env.temperature = temperature;
  env.humidity = humidity;
  env.illuminance = illuminance;
  env.occupancy = occupancy;
  return env;
}

function makeCondition(field: EnvField, op: CompareOp, value: number): RuleCondition {
  const condition: RuleCondition = new RuleCondition();
  condition.field = field;
  condition.op = op;
  condition.value = value;
  return condition;
}

function makeAction(device: DeviceType, property: DeviceProperty, value: number): RuleAction {
  const action: RuleAction = new RuleAction();
  action.device = device;
  action.property = property;
  action.value = value;
  return action;
}

function makeRule(id: string, name: string, priority: number, logic: LogicOp,
  conditions: RuleCondition[], actions: RuleAction[]): AutomationRule {
  const rule: AutomationRule = new AutomationRule();
  rule.id = id;
  rule.name = name;
  rule.enabled = true;
  rule.priority = priority;
  rule.logic = logic;
  rule.conditions = conditions;
  rule.actions = actions;
  return rule;
}

/** 两组可一键套用的模拟场景 */
export function getScenarioPresets(): ScenarioPreset[] {
  const presets: ScenarioPreset[] = [];
  presets.push(new ScenarioPreset('夏季午休', '高温低湿、光线充足、宿舍有人',
    makeEnv(32, 45, 900, true)));
  presets.push(new ScenarioPreset('阴雨傍晚', '气温偏低、湿度很高、光线昏暗、宿舍有人',
    makeEnv(21, 82, 120, true)));
  return presets;
}

/** 首次启动灌入的默认规则 */
export function createDefaultRules(): AutomationRule[] {
  const rules: AutomationRule[] = [];

  // 1 高温开空调：优先级最高，先占住「空调开关」这个属性
  rules.push(makeRule('rule_ac_on', '高温开空调', 1, LogicOp.AND,
    [makeCondition(EnvField.TEMPERATURE, CompareOp.GT, 28)],
    [makeAction(DeviceType.AC, DeviceProperty.POWER, 1)]));

  // 2 无人断电：一条规则控制两台设备
  rules.push(makeRule('rule_away_off', '无人断电', 1, LogicOp.AND,
    [makeCondition(EnvField.OCCUPANCY, CompareOp.EQ, 0)],
    [
      makeAction(DeviceType.LIGHT, DeviceProperty.POWER, 0),
      makeAction(DeviceType.AC, DeviceProperty.POWER, 0)
    ]));

  // 3 阴天补光：双条件 + 与逻辑，两个条件同时成立才动作
  rules.push(makeRule('rule_dim_light', '阴天补光', 2, LogicOp.AND,
    [
      makeCondition(EnvField.ILLUMINANCE, CompareOp.LT, 200),
      makeCondition(EnvField.OCCUPANCY, CompareOp.EQ, 1)
    ],
    [
      makeAction(DeviceType.LIGHT, DeviceProperty.POWER, 1),
      makeAction(DeviceType.LIGHT, DeviceProperty.BRIGHTNESS, 70)
    ]));

  // 4 夜间闭帘：光照过强时拉上窗帘
  rules.push(makeRule('rule_curtain_close', '强光闭帘', 3, LogicOp.AND,
    [makeCondition(EnvField.ILLUMINANCE, CompareOp.GT, 1500)],
    [makeAction(DeviceType.CURTAIN, DeviceProperty.OPEN_LEVEL, 0)]));

  // 5 干燥加湿：湿度偏低时打开加湿器
  rules.push(makeRule('rule_humidify', '干燥加湿', 4, LogicOp.AND,
    [makeCondition(EnvField.HUMIDITY, CompareOp.LT, 35)],
    [makeAction(DeviceType.HUMIDIFIER, DeviceProperty.POWER, 1)]));

  // 6 节能关空调：与规则 1 争抢「空调开关」，优先级低，用来演示冲突裁决
  rules.push(makeRule('rule_ac_off', '节能关空调', 6, LogicOp.AND,
    [makeCondition(EnvField.TEMPERATURE, CompareOp.GT, 28)],
    [makeAction(DeviceType.AC, DeviceProperty.POWER, 0)]));

  return rules;
}
