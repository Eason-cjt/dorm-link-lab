/**
 * 规则引擎自动化测试
 *
 * 覆盖三类场景：
 *  - 正常：单条件命中、多动作联动
 *  - 边界：阈值恰好相等、动作值越界
 *  - 异常：空条件、规则停用、规则之间争抢同一设备属性（冲突裁决）
 */

import { describe, expect, it } from '@ohos/hypium';
import {
  createDefaultDevices,
  DeviceProperty,
  DeviceState,
  DeviceType,
  findDevice,
  readDeviceProperty,
  writeDeviceProperty
} from '../main/ets/model/DeviceModel';
import { CompareOp, EnvData, EnvField } from '../main/ets/model/EnvModel';
import { AutomationRule, LogicOp, RuleAction, RuleCondition } from '../main/ets/model/RuleModel';
import { RuleEngine } from '../main/ets/engine/RuleEngine';

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

function makeRule(id: string, name: string, priority: number, conditions: RuleCondition[],
  actions: RuleAction[], logic: LogicOp = LogicOp.AND): AutomationRule {
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

export default function ruleEngineTest() {
  describe('RuleEngineTest', () => {

    // ---------- 正常场景 ----------
    it('normal_high_temperature_turns_on_ac', 0, () => {
      const rule: AutomationRule = makeRule('r_ac', '高温开空调', 1,
        [makeCondition(EnvField.TEMPERATURE, CompareOp.GT, 28)],
        [makeAction(DeviceType.AC, DeviceProperty.POWER, 1)]);
      const devices: DeviceState[] = createDefaultDevices();
      const result = RuleEngine.run([rule], makeEnv(32, 50, 300, true), devices);

      expect(result.hits.length).assertEqual(1);
      expect(result.hits[0].ruleName).assertEqual('高温开空调');
      expect(result.hits[0].order).assertEqual(1);
      expect(result.changes.length).assertEqual(1);
      expect(readDeviceProperty(findDevice(result.devicesAfter, DeviceType.AC), DeviceProperty.POWER)).assertEqual(1);
    });

    it('normal_multi_action_rule_changes_two_devices', 0, () => {
      const rule: AutomationRule = makeRule('r_away', '无人断电', 1,
        [makeCondition(EnvField.OCCUPANCY, CompareOp.EQ, 0)],
        [
          makeAction(DeviceType.LIGHT, DeviceProperty.POWER, 0),
          makeAction(DeviceType.AC, DeviceProperty.POWER, 0)
        ]);
      const devices: DeviceState[] = createDefaultDevices();
      // 先把两台设备打开，才能观察「关」的变化
      writeDeviceProperty(findDevice(devices, DeviceType.LIGHT), DeviceProperty.POWER, 1);
      writeDeviceProperty(findDevice(devices, DeviceType.AC), DeviceProperty.POWER, 1);

      const result = RuleEngine.run([rule], makeEnv(26, 50, 300, false), devices);
      expect(result.changes.length).assertEqual(2);
      expect(readDeviceProperty(findDevice(result.devicesAfter, DeviceType.LIGHT), DeviceProperty.POWER)).assertEqual(0);
      expect(readDeviceProperty(findDevice(result.devicesAfter, DeviceType.AC), DeviceProperty.POWER)).assertEqual(0);
    });

    // ---------- 边界场景 ----------
    it('boundary_equal_value_with_greater_than_not_triggered', 0, () => {
      const rule: AutomationRule = makeRule('r_gt', '大于28度开空调', 1,
        [makeCondition(EnvField.TEMPERATURE, CompareOp.GT, 28)],
        [makeAction(DeviceType.AC, DeviceProperty.POWER, 1)]);
      // 温度恰好 28，严格大于不成立
      const result = RuleEngine.run([rule], makeEnv(28, 50, 300, true), createDefaultDevices());
      expect(result.hits.length).assertEqual(0);
      expect(result.skipped.length).assertEqual(1);
      expect(result.skipped[0].reason).assertEqual('环境条件未满足');
    });

    it('boundary_equal_value_with_greater_equal_triggered', 0, () => {
      const rule: AutomationRule = makeRule('r_gte', '大于等于28度开空调', 1,
        [makeCondition(EnvField.TEMPERATURE, CompareOp.GTE, 28)],
        [makeAction(DeviceType.AC, DeviceProperty.POWER, 1)]);
      const result = RuleEngine.run([rule], makeEnv(28, 50, 300, true), createDefaultDevices());
      expect(result.hits.length).assertEqual(1);
    });

    it('boundary_action_value_is_clamped', 0, () => {
      const device: DeviceState = new DeviceState(DeviceType.LIGHT, '主灯');
      // 亮度上限 100，写入 150 应被收敛
      writeDeviceProperty(device, DeviceProperty.BRIGHTNESS, 150);
      expect(device.brightness).assertEqual(100);
      writeDeviceProperty(device, DeviceProperty.BRIGHTNESS, -20);
      expect(device.brightness).assertEqual(0);
    });

    // ---------- 多条件规则 ----------
    it('multi_condition_and_both_satisfied', 0, () => {
      const rule: AutomationRule = makeRule('r_dim', '阴天补光', 2,
        [
          makeCondition(EnvField.ILLUMINANCE, CompareOp.LT, 200),
          makeCondition(EnvField.OCCUPANCY, CompareOp.EQ, 1)
        ],
        [makeAction(DeviceType.LIGHT, DeviceProperty.POWER, 1)],
        LogicOp.AND);
      // 光照 120 且有人 → 两个条件都成立
      const result = RuleEngine.run([rule], makeEnv(24, 50, 120, true), createDefaultDevices());
      expect(result.hits.length).assertEqual(1);
      expect(readDeviceProperty(findDevice(result.devicesAfter, DeviceType.LIGHT), DeviceProperty.POWER)).assertEqual(1);
    });

    it('multi_condition_and_one_failed', 0, () => {
      const rule: AutomationRule = makeRule('r_dim', '阴天补光', 2,
        [
          makeCondition(EnvField.ILLUMINANCE, CompareOp.LT, 200),
          makeCondition(EnvField.OCCUPANCY, CompareOp.EQ, 1)
        ],
        [makeAction(DeviceType.LIGHT, DeviceProperty.POWER, 1)],
        LogicOp.AND);
      // 光照 120 但没人 → 与逻辑不成立
      const result = RuleEngine.run([rule], makeEnv(24, 50, 120, false), createDefaultDevices());
      expect(result.hits.length).assertEqual(0);
    });

    it('multi_condition_or_any_satisfied', 0, () => {
      const rule: AutomationRule = makeRule('r_or', '干燥或高温开加湿', 3,
        [
          makeCondition(EnvField.HUMIDITY, CompareOp.LT, 30),
          makeCondition(EnvField.TEMPERATURE, CompareOp.GT, 35)
        ],
        [makeAction(DeviceType.HUMIDIFIER, DeviceProperty.POWER, 1)],
        LogicOp.OR);
      // 湿度 50 不满足，但温度 38 满足 → 或逻辑触发
      const result = RuleEngine.run([rule], makeEnv(38, 50, 300, true), createDefaultDevices());
      expect(result.hits.length).assertEqual(1);
    });

    // ---------- 异常场景 ----------
    it('abnormal_rule_without_condition_never_triggers', 0, () => {
      const rule: AutomationRule = makeRule('r_empty', '空条件规则', 1, [],
        [makeAction(DeviceType.AC, DeviceProperty.POWER, 1)]);
      const result = RuleEngine.run([rule], makeEnv(35, 50, 300, true), createDefaultDevices());
      expect(result.hits.length).assertEqual(0);
      expect(result.skipped.length).assertEqual(1);
      expect(result.skipped[0].reason).assertEqual('未配置触发条件');
    });

    it('abnormal_disabled_rule_is_skipped', 0, () => {
      const rule: AutomationRule = makeRule('r_off', '高温开空调', 1,
        [makeCondition(EnvField.TEMPERATURE, CompareOp.GT, 28)],
        [makeAction(DeviceType.AC, DeviceProperty.POWER, 1)]);
      rule.enabled = false;
      const result = RuleEngine.run([rule], makeEnv(35, 50, 300, true), createDefaultDevices());
      expect(result.hits.length).assertEqual(0);
      expect(result.skipped[0].reason).assertEqual('规则已停用');
    });

    // ---------- 冲突与顺序 ----------
    it('conflict_higher_priority_wins', 0, () => {
      const turnOn: AutomationRule = makeRule('r_a', '高温开空调', 1,
        [makeCondition(EnvField.TEMPERATURE, CompareOp.GT, 28)],
        [makeAction(DeviceType.AC, DeviceProperty.POWER, 1)]);
      const turnOff: AutomationRule = makeRule('r_b', '节能关空调', 6,
        [makeCondition(EnvField.TEMPERATURE, CompareOp.GT, 28)],
        [makeAction(DeviceType.AC, DeviceProperty.POWER, 0)]);
      const result = RuleEngine.run([turnOn, turnOff], makeEnv(32, 50, 300, true), createDefaultDevices());

      // 两条规则都命中
      expect(result.hits.length).assertEqual(2);
      // 但空调最终是「开」——优先级 1 先写入，优先级 6 不覆盖
      expect(readDeviceProperty(findDevice(result.devicesAfter, DeviceType.AC), DeviceProperty.POWER)).assertEqual(1);
      // 冲突被记录，胜者是高优先级规则
      expect(result.conflicts.length).assertEqual(1);
      expect(result.conflicts[0].winnerRuleId).assertEqual('r_a');
      expect(result.conflicts[0].loserRuleId).assertEqual('r_b');
    });

    it('execution_order_follows_priority_ascending', 0, () => {
      const low: AutomationRule = makeRule('r_low', '低优先级', 8,
        [makeCondition(EnvField.TEMPERATURE, CompareOp.GT, 10)],
        [makeAction(DeviceType.CURTAIN, DeviceProperty.OPEN_LEVEL, 30)]);
      const high: AutomationRule = makeRule('r_high', '高优先级', 1,
        [makeCondition(EnvField.TEMPERATURE, CompareOp.GT, 10)],
        [makeAction(DeviceType.CURTAIN, DeviceProperty.OPEN_LEVEL, 80)]);
      // 故意把低优先级规则排在数组前面，验证引擎会自行排序
      const result = RuleEngine.run([low, high], makeEnv(26, 50, 300, true), createDefaultDevices());

      expect(result.hits.length).assertEqual(2);
      expect(result.hits[0].ruleId).assertEqual('r_high');
      expect(result.hits[0].order).assertEqual(1);
      expect(result.hits[1].ruleId).assertEqual('r_low');
      expect(result.hits[1].order).assertEqual(2);
      // 高优先级先写入 80，低优先级的 30 被判定为冲突而不覆盖
      expect(readDeviceProperty(findDevice(result.devicesAfter, DeviceType.CURTAIN),
        DeviceProperty.OPEN_LEVEL)).assertEqual(80);
    });

    it('engine_does_not_mutate_input_devices', 0, () => {
      const rule: AutomationRule = makeRule('r_ac', '高温开空调', 1,
        [makeCondition(EnvField.TEMPERATURE, CompareOp.GT, 28)],
        [makeAction(DeviceType.AC, DeviceProperty.POWER, 1)]);
      const devices: DeviceState[] = createDefaultDevices();
      const before: number = readDeviceProperty(findDevice(devices, DeviceType.AC), DeviceProperty.POWER);
      const result = RuleEngine.run([rule], makeEnv(32, 50, 300, true), devices);
      const after: number = readDeviceProperty(findDevice(devices, DeviceType.AC), DeviceProperty.POWER);

      // 引擎在副本上推演，入参设备状态不应被改动
      expect(before).assertEqual(after);
      expect(result.devicesAfter !== devices).assertTrue();
    });
  });
}
