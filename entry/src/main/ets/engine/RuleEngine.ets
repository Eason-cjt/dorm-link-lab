/**
 * 规则引擎
 *
 * 职责：给定一组规则和一份环境快照，计算出哪些规则被触发、设备应如何变化、
 * 哪些控制相互冲突以及最终执行顺序。
 *
 * 设计要点：
 * 1. 纯函数式推演——在设备副本上计算，不改动调用方传入的真实状态；
 * 2. 执行顺序确定——先按优先级升序，优先级相同再按规则 id 升序，
 *    保证同一份输入每次得到完全相同的输出（可测试、可复现）；
 * 3. 冲突先到先得——同一设备同一属性被多条规则控制且目标值不同时，
 *    优先级高的规则先生效并占位，后续规则不覆盖，同时写入冲突记录。
 */

import {
  DeviceProperty,
  DeviceState,
  readDeviceProperty,
  writeDeviceProperty,
  cloneDevice,
  findDevice,
  formatPropertyValue,
  deviceLabel
} from '../model/DeviceModel';
import {
  CompareOp,
  EnvData,
  cloneEnv,
  envFieldLabel,
  formatEnvValue,
  readEnvField
} from '../model/EnvModel';
import { AutomationRule, LogicOp, RuleCondition } from '../model/RuleModel';
import { ConflictRecord, DeviceChange, ExecutionResult, RuleHit, SkippedRule } from '../model/LogModel';

/** 已被某条规则写入的设备属性占位记录，用于冲突判定 */
class AppliedRecord {
  ruleId: string = '';
  ruleName: string = '';
  priority: number = 0;
  value: number = 0;
}

/** 一次冲突提示（用于保存规则时提示潜在冲突） */
export class ConflictHint {
  deviceLabelText: string = '';
  propertyLabelText: string = '';
  ruleA: string = '';
  ruleB: string = '';
  message: string = '';
}

export class RuleEngine {

  /**
   * 判断单个条件是否成立。
   * 布尔字段（是否有人）以 1/0 参与比较，因此与数值字段共用同一套运算符。
   */
  static matchCondition(condition: RuleCondition, env: EnvData): boolean {
    const actual: number = readEnvField(env, condition.field);
    const target: number = condition.value;
    switch (condition.op) {
      case CompareOp.GT:
        return actual > target;
      case CompareOp.GTE:
        return actual >= target;
      case CompareOp.LT:
        return actual < target;
      case CompareOp.LTE:
        return actual <= target;
      case CompareOp.EQ:
        return actual === target;
      case CompareOp.NE:
        return actual !== target;
      default:
        return false;
    }
  }

  /**
   * 判断整条规则是否命中。
   * 单条件规则直接取该条件结果；多条件规则按 logic 做与/或。
   * 无条件的规则永远不命中，避免「空规则无条件触发」。
   */
  static evaluate(rule: AutomationRule, env: EnvData): boolean {
    if (rule.conditions.length === 0) {
      return false;
    }
    if (rule.logic === LogicOp.OR) {
      for (let i = 0; i < rule.conditions.length; i++) {
        if (RuleEngine.matchCondition(rule.conditions[i], env)) {
          return true;
        }
      }
      return false;
    }
    for (let i = 0; i < rule.conditions.length; i++) {
      if (!RuleEngine.matchCondition(rule.conditions[i], env)) {
        return false;
      }
    }
    return true;
  }

  /** 把规则的条件翻译成「温度 > 28℃ 且 湿度 >= 60%」这样的可读文本 */
  static conditionSummary(rule: AutomationRule): string {
    const parts: string[] = [];
    for (let i = 0; i < rule.conditions.length; i++) {
      const c: RuleCondition = rule.conditions[i];
      parts.push(`${envFieldLabel(c.field)} ${c.op} ${formatEnvValue(c.field, c.value)}`);
    }
    const joiner: string = rule.logic === LogicOp.AND ? ' 且 ' : ' 或 ';
    return parts.join(joiner);
  }

  /**
   * 执行一次联动推演。
   * @param rules 全部规则（含停用规则，引擎内部会跳过并记录原因）
   * @param env 环境快照
   * @param devices 当前设备状态（不会被修改）
   * @param scenarioName 场景名，手工调参时传空串
   */
  static run(rules: AutomationRule[], env: EnvData, devices: DeviceState[],
    scenarioName: string = ''): ExecutionResult {
    const result: ExecutionResult = new ExecutionResult();
    result.id = `exec_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
    result.timestamp = Date.now();
    result.scenarioName = scenarioName;
    result.env = cloneEnv(env);

    // 在副本上推演，保证调用方的真实设备状态不被污染
    const working: DeviceState[] = [];
    for (let i = 0; i < devices.length; i++) {
      working.push(cloneDevice(devices[i]));
    }

    // 执行顺序：优先级升序（数字小=优先），同级按 id 升序兜底
    const ordered: AutomationRule[] = [];
    for (let i = 0; i < rules.length; i++) {
      ordered.push(rules[i]);
    }
    ordered.sort((a: AutomationRule, b: AutomationRule): number => {
      if (a.priority !== b.priority) {
        return a.priority - b.priority;
      }
      if (a.id === b.id) {
        return 0;
      }
      return a.id < b.id ? -1 : 1;
    });

    const applied: Map<string, AppliedRecord> = new Map<string, AppliedRecord>();
    let order: number = 0;

    for (let r = 0; r < ordered.length; r++) {
      const rule: AutomationRule = ordered[r];

      if (!rule.enabled) {
        RuleEngine.markSkipped(result, rule, '规则已停用');
        continue;
      }
      if (rule.conditions.length === 0) {
        RuleEngine.markSkipped(result, rule, '未配置触发条件');
        continue;
      }
      if (rule.actions.length === 0) {
        RuleEngine.markSkipped(result, rule, '未配置设备动作');
        continue;
      }
      if (!RuleEngine.evaluate(rule, env)) {
        RuleEngine.markSkipped(result, rule, '环境条件未满足');
        continue;
      }

      order = order + 1;
      const hit: RuleHit = new RuleHit();
      hit.ruleId = rule.id;
      hit.ruleName = rule.name;
      hit.priority = rule.priority;
      hit.order = order;
      hit.conditionSummary = RuleEngine.conditionSummary(rule);
      result.hits.push(hit);

      for (let a = 0; a < rule.actions.length; a++) {
        const action = rule.actions[a];
        const device: DeviceState = findDevice(working, action.device);
        const key: string = `${action.device}:${action.property}`;
        const occupied: AppliedRecord | undefined = applied.get(key);
        const currentValue: number = readDeviceProperty(device, action.property);

        // 同一属性已被更高优先级规则写入，且目标值不同 → 冲突，不覆盖
        if (occupied !== undefined && occupied.value !== action.value) {
          const conflict: ConflictRecord = new ConflictRecord();
          conflict.deviceType = action.device;
          conflict.deviceName = deviceLabel(action.device);
          conflict.property = action.property;
          conflict.winnerRuleId = occupied.ruleId;
          conflict.winnerRuleName = occupied.ruleName;
          conflict.winnerValue = occupied.value;
          conflict.loserRuleId = rule.id;
          conflict.loserRuleName = rule.name;
          conflict.loserValue = action.value;
          conflict.reason =
            `规则「${occupied.ruleName}」(优先级 ${occupied.priority}) 先于「${rule.name}」(优先级 ${rule.priority}) 生效，保留前者设定的 ${formatPropertyValue(action.property, occupied.value)}`;
          result.conflicts.push(conflict);
          continue;
        }

        if (occupied === undefined) {
          const record: AppliedRecord = new AppliedRecord();
          record.ruleId = rule.id;
          record.ruleName = rule.name;
          record.priority = rule.priority;
          record.value = action.value;
          applied.set(key, record);
        }

        if (currentValue !== action.value) {
          const change: DeviceChange = new DeviceChange();
          change.deviceType = action.device;
          change.deviceName = deviceLabel(action.device);
          change.property = action.property;
          change.fromValue = currentValue;
          change.toValue = action.value;
          change.ruleId = rule.id;
          change.ruleName = rule.name;
          result.changes.push(change);
          writeDeviceProperty(device, action.property, action.value);
        }
      }
    }

    result.devicesAfter = working;
    return result;
  }

  private static markSkipped(result: ExecutionResult, rule: AutomationRule, reason: string): void {
    const skipped: SkippedRule = new SkippedRule();
    skipped.ruleId = rule.id;
    skipped.ruleName = rule.name;
    skipped.reason = reason;
    result.skipped.push(skipped);
  }

  /**
   * 检查规则之间是否存在「同优先级争抢同一设备属性」的隐患。
   * 优先级不同时由引擎按顺序裁决，属于正常设计；同优先级则依赖 id 排序，
   * 结果虽然确定但对用户不可预期，需要在保存时提示。
   */
  static detectConflictHints(rules: AutomationRule[]): ConflictHint[] {
    const hints: ConflictHint[] = [];
    for (let i = 0; i < rules.length; i++) {
      for (let j = i + 1; j < rules.length; j++) {
        const a: AutomationRule = rules[i];
        const b: AutomationRule = rules[j];
        if (!a.enabled || !b.enabled) {
          continue;
        }
        if (a.priority !== b.priority) {
          continue;
        }
        for (let x = 0; x < a.actions.length; x++) {
          for (let y = 0; y < b.actions.length; y++) {
            const actA = a.actions[x];
            const actB = b.actions[y];
            if (actA.device === actB.device && actA.property === actB.property && actA.value !== actB.value) {
              const hint: ConflictHint = new ConflictHint();
              hint.deviceLabelText = deviceLabel(actA.device);
              hint.propertyLabelText = formatPropertyValue(actA.property, actA.value);
              hint.ruleA = a.name;
              hint.ruleB = b.name;
              hint.message =
                `「${a.name}」与「${b.name}」同为优先级 ${a.priority}，却对${deviceLabel(actA.device)}给出不同目标值，建议调整其中一条的优先级`;
              hints.push(hint);
            }
          }
        }
      }
    }
    return hints;
  }
}
