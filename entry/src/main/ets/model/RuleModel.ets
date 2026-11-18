/**
 * 自动化规则模型
 * 一条规则 = 1~2 个环境条件 + 逻辑关系 + 1~n 个设备动作 + 优先级。
 */

import { DeviceProperty, DeviceType } from './DeviceModel';
import { CompareOp, EnvField } from './EnvModel';

/** 多条件之间的逻辑关系 */
export enum LogicOp {
  AND = 'AND',
  OR = 'OR'
}

/** 单个环境条件 */
export class RuleCondition {
  field: EnvField = EnvField.TEMPERATURE;
  op: CompareOp = CompareOp.GT;
  /** 比较值，布尔字段用 1/0 */
  value: number = 0;
}

/** 单个设备动作 */
export class RuleAction {
  device: DeviceType = DeviceType.LIGHT;
  property: DeviceProperty = DeviceProperty.POWER;
  /** 目标值，布尔属性用 1/0 */
  value: number = 0;
}

/** 一条自动化规则 */
export class AutomationRule {
  id: string = '';
  name: string = '';
  enabled: boolean = true;
  /** 优先级，数字越小越先执行，取值 1-9 */
  priority: number = 5;
  logic: LogicOp = LogicOp.AND;
  conditions: RuleCondition[] = [];
  actions: RuleAction[] = [];
}

/** 是否为多条件规则（自由函数，避免依赖类原型） */
export function isMultiCondition(rule: AutomationRule): boolean {
  return rule.conditions.length >= 2;
}

/** 生成规则主键 */
export function newRuleId(): string {
  return `rule_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
}

/** 深拷贝规则，编辑页在副本上修改，保存时才写回 */
export function cloneRule(rule: AutomationRule): AutomationRule {
  const copy: AutomationRule = new AutomationRule();
  copy.id = rule.id;
  copy.name = rule.name;
  copy.enabled = rule.enabled;
  copy.priority = rule.priority;
  copy.logic = rule.logic;
  for (let i = 0; i < rule.conditions.length; i++) {
    const c: RuleCondition = new RuleCondition();
    c.field = rule.conditions[i].field;
    c.op = rule.conditions[i].op;
    c.value = rule.conditions[i].value;
    copy.conditions.push(c);
  }
  for (let i = 0; i < rule.actions.length; i++) {
    const a: RuleAction = new RuleAction();
    a.device = rule.actions[i].device;
    a.property = rule.actions[i].property;
    a.value = rule.actions[i].value;
    copy.actions.push(a);
  }
  return copy;
}

/** 新建一条空白规则 */
export function createEmptyRule(): AutomationRule {
  const rule: AutomationRule = new AutomationRule();
  rule.id = newRuleId();
  rule.name = '新规则';
  rule.enabled = true;
  rule.priority = 5;
  rule.logic = LogicOp.AND;
  const condition: RuleCondition = new RuleCondition();
  condition.field = EnvField.TEMPERATURE;
  condition.op = CompareOp.GT;
  condition.value = 28;
  rule.conditions.push(condition);
  const action: RuleAction = new RuleAction();
  action.device = DeviceType.AC;
  action.property = DeviceProperty.POWER;
  action.value = 1;
  rule.actions.push(action);
  return rule;
}

/** 优先级文本 */
export function priorityLabel(priority: number): string {
  if (priority <= 2) {
    return '高';
  }
  if (priority <= 5) {
    return '中';
  }
  return '低';
}
