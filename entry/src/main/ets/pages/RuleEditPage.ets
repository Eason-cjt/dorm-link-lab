/**
 * 规则编辑页：条件（1~2 条）+ 逻辑关系 + 设备动作（1~3 个）+ 优先级。
 *
 * 编辑在规则副本上进行，点「保存」才写回 AppStore 并落盘，
 * 直接返回则丢弃改动。
 */

import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import {
  DeviceMeta,
  DeviceProperty,
  DeviceType,
  deviceLabel,
  formatPropertyValue,
  getDeviceMeta,
  getDeviceMetas,
  propertyLabel
} from '../model/DeviceModel';
import {
  CompareOp,
  EnvField,
  envFieldLabel,
  envFieldMax,
  envFieldMin,
  envFieldUnit,
  formatEnvValue,
  isBooleanField
} from '../model/EnvModel';
import {
  AutomationRule,
  cloneRule,
  createEmptyRule,
  LogicOp,
  RuleAction,
  RuleCondition
} from '../model/RuleModel';
import { AppStore } from '../service/AppStore';

const ENV_FIELDS: EnvField[] = [
  EnvField.TEMPERATURE,
  EnvField.HUMIDITY,
  EnvField.ILLUMINANCE,
  EnvField.OCCUPANCY
];

const COMPARE_OPS: CompareOp[] = [
  CompareOp.GT,
  CompareOp.GTE,
  CompareOp.LT,
  CompareOp.LTE,
  CompareOp.EQ,
  CompareOp.NE
];

function defaultForField(field: EnvField): number {
  switch (field) {
    case EnvField.TEMPERATURE:
      return 28;
    case EnvField.HUMIDITY:
      return 60;
    case EnvField.ILLUMINANCE:
      return 200;
    default:
      return 1;
  }
}

@Entry
@Component
struct RuleEditPage {
  @State rule: AutomationRule = new AutomationRule();
  @State isEditing: boolean = false;
  @State ready: boolean = false;

  aboutToAppear(): void {
    const params: Record<string, Object> = router.getParams() as Record<string, Object>;
    let ruleId: string = 'new';
    if (params !== undefined && params['ruleId'] !== undefined) {
      ruleId = params['ruleId'] as string;
    }
    const store: AppStore = AppStore.getInstance();
    const index: number = store.indexOfRule(ruleId);
    if (index >= 0) {
      this.rule = cloneRule(store.rules[index]);
      this.isEditing = true;
    } else {
      this.rule = createEmptyRule();
      this.isEditing = false;
    }
    this.ready = true;
  }

  /** 深拷贝后重新赋值，触发界面刷新（ArkUI 不监听数组/对象的深层变更） */
  private touch(): void {
    this.rule = cloneRule(this.rule);
  }

  private async save(): Promise<void> {
    if (this.rule.name.trim() === '') {
      promptAction.showToast({ message: '请填写规则名称' });
      return;
    }
    if (this.rule.conditions.length === 0) {
      promptAction.showToast({ message: '至少要有一个触发条件' });
      return;
    }
    if (this.rule.actions.length === 0) {
      promptAction.showToast({ message: '至少要有一个设备动作' });
      return;
    }
    const store: AppStore = AppStore.getInstance();
    const index: number = store.indexOfRule(this.rule.id);
    if (index >= 0) {
      store.rules[index] = cloneRule(this.rule);
    } else {
      store.rules.push(cloneRule(this.rule));
    }
    await store.persistRules();
    promptAction.showToast({ message: '规则已保存' });
    router.back();
  }

  private async remove(): Promise<void> {
    const store: AppStore = AppStore.getInstance();
    const index: number = store.indexOfRule(this.rule.id);
    if (index >= 0) {
      store.rules.splice(index, 1);
      await store.persistRules();
    }
    promptAction.showToast({ message: '规则已删除' });
    router.back();
  }

  private addCondition(): void {
    if (this.rule.conditions.length >= 2) {
      promptAction.showToast({ message: '最多支持两个条件' });
      return;
    }
    const condition: RuleCondition = new RuleCondition();
    condition.field = EnvField.HUMIDITY;
    condition.op = CompareOp.GTE;
    condition.value = 60;
    this.rule.conditions.push(condition);
    this.touch();
  }

  private removeCondition(index: number): void {
    this.rule.conditions.splice(index, 1);
    this.touch();
  }

  private addAction(): void {
    if (this.rule.actions.length >= 3) {
      promptAction.showToast({ message: '最多支持三个动作' });
      return;
    }
    const action: RuleAction = new RuleAction();
    action.device = DeviceType.HUMIDIFIER;
    action.property = DeviceProperty.POWER;
    action.value = 1;
    this.rule.actions.push(action);
    this.touch();
  }

  private removeAction(index: number): void {
    this.rule.actions.splice(index, 1);
    this.touch();
  }

  @Builder
  sectionTitle(title: string, hint: string) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#374151')
      Blank()
      Text(hint)
        .fontSize(11)
        .fontColor('#9CA3AF')
    }
    .width('100%')
  }

  @Builder
  segmentRow(options: string[], selectedIndex: number, onPick: (index: number) => void) {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(options, (label: string, index: number) => {
        Text(label)
          .fontSize(12)
          .fontColor(selectedIndex === index ? '#FFFFFF' : '#4B5563')
          .backgroundColor(selectedIndex === index ? '#2563EB' : '#F3F4F6')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .borderRadius(8)
          .margin({ right: 6, bottom: 6 })
          .onClick(() => {
            onPick(index);
          })
      }, (label: string, index: number) => `${label}_${index}`)
    }
    .width('100%')
  }

  @Builder
  valueEditor(field: EnvField, index: number) {
    if (isBooleanField(field)) {
      Row({ space: 6 }) {
        ForEach(['无人', '有人'], (label: string, i: number) => {
          Text(label)
            .fontSize(12)
            .fontColor(this.rule.conditions[index].value === i ? '#FFFFFF' : '#4B5563')
            .backgroundColor(this.rule.conditions[index].value === i ? '#2563EB' : '#F3F4F6')
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(8)
            .onClick(() => {
              this.rule.conditions[index].value = i;
              this.touch();
            })
        }, (label: string) => label)
      }
      .width('100%')
    } else {
      Row({ space: 10 }) {
        Slider({
          value: this.rule.conditions[index].value,
          min: envFieldMin(field),
          max: envFieldMax(field),
          step: field === EnvField.ILLUMINANCE ? 50 : 1,
          style: SliderStyle.OutSet
        })
          .layoutWeight(1)
          .selectedColor('#2563EB')
          .onChange((value: number) => {
            this.rule.conditions[index].value = Math.round(value);
            this.touch();
          })
        Text(formatEnvValue(field, this.rule.conditions[index].value))
          .fontSize(12)
          .fontColor('#111827')
          .width(64)
          .textAlign(TextAlign.End)
      }
      .width('100%')
    }
  }

  @Builder
  conditionCard(condition: RuleCondition, index: number) {
    Column({ space: 8 }) {
      Row() {
        Text(`条件 ${index + 1}`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2563EB')
        Blank()
        if (this.rule.conditions.length > 1) {
          Text('删除')
            .fontSize(11)
            .fontColor('#DC2626')
            .onClick(() => {
              this.removeCondition(index);
            })
        }
      }
      .width('100%')

      // 字段
      this.segmentRow(
        ENV_FIELDS.map((f: EnvField) => envFieldLabel(f)),
        ENV_FIELDS.indexOf(condition.field),
        (picked: number) => {
          this.rule.conditions[index].field = ENV_FIELDS[picked];
          this.rule.conditions[index].value = defaultForField(ENV_FIELDS[picked]);
          this.touch();
        }
      )

      // 运算符
      this.segmentRow(
        COMPARE_OPS.map((op: CompareOp) => op as string),
        COMPARE_OPS.indexOf(condition.op),
        (picked: number) => {
          this.rule.conditions[index].op = COMPARE_OPS[picked];
          this.touch();
        }
      )

      // 值
      this.valueEditor(condition.field, index)

      Text(`${envFieldLabel(condition.field)} ${condition.op} ${formatEnvValue(condition.field, condition.value)}`)
        .fontSize(11)
        .fontColor('#6B7280')
        .width('100%')
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F9FAFB')
    .borderRadius(10)
  }

  @Builder
  actionCard(action: RuleAction, index: number) {
    Column({ space: 8 }) {
      Row() {
        Text(`动作 ${index + 1}`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#0D9488')
        Blank()
        if (this.rule.actions.length > 1) {
          Text('删除')
            .fontSize(11)
            .fontColor('#DC2626')
            .onClick(() => {
              this.removeAction(index);
            })
        }
      }
      .width('100%')

      // 设备
      this.segmentRow(
        getDeviceMetas().map((m: DeviceMeta) => m.label),
        this.deviceIndexOf(action.device),
        (picked: number) => {
          const metas: DeviceMeta[] = getDeviceMetas();
          const chosen: DeviceMeta = metas[picked];
          this.rule.actions[index].device = chosen.type;
          this.rule.actions[index].property = chosen.properties[0];
          this.rule.actions[index].value =
            chosen.properties[0] === DeviceProperty.POWER ? 1 : 50;
          this.touch();
        }
      )

      // 属性
      this.segmentRow(
        getDeviceMeta(action.device).properties.map((p: DeviceProperty) => propertyLabel(p)),
        getDeviceMeta(action.device).properties.indexOf(action.property),
        (picked: number) => {
          const properties: DeviceProperty[] = getDeviceMeta(this.rule.actions[index].device).properties;
          this.rule.actions[index].property = properties[picked];
          this.rule.actions[index].value = properties[picked] === DeviceProperty.POWER ? 1 : 50;
          this.touch();
        }
      )

      // 值
      this.actionValueEditor(action, index)

      Text(`${deviceLabel(action.device)} → ${propertyLabel(action.property)} 设为 ${formatPropertyValue(action.property, action.value)}`)
        .fontSize(11)
        .fontColor('#6B7280')
        .width('100%')
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F9FAFB')
    .borderRadius(10)
  }

  @Builder
  actionValueEditor(action: RuleAction, index: number) {
    if (action.property === DeviceProperty.POWER) {
      Row({ space: 6 }) {
        ForEach(['关', '开'], (label: string, i: number) => {
          Text(label)
            .fontSize(12)
            .fontColor(this.rule.actions[index].value === i ? '#FFFFFF' : '#4B5563')
            .backgroundColor(this.rule.actions[index].value === i ? '#0D9488' : '#F3F4F6')
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .borderRadius(8)
            .onClick(() => {
              this.rule.actions[index].value = i;
              this.touch();
            })
        }, (label: string) => label)
      }
      .width('100%')
    } else {
      Row({ space: 10 }) {
        Slider({
          value: this.rule.actions[index].value,
          min: action.property === DeviceProperty.TARGET_TEMP ? 16 : 0,
          max: action.property === DeviceProperty.TARGET_TEMP ? 30 : 100,
          step: 1,
          style: SliderStyle.OutSet
        })
          .layoutWeight(1)
          .selectedColor('#0D9488')
          .onChange((value: number) => {
            this.rule.actions[index].value = Math.round(value);
            this.touch();
          })
        Text(formatPropertyValue(action.property, this.rule.actions[index].value))
          .fontSize(12)
          .fontColor('#111827')
          .width(56)
          .textAlign(TextAlign.End)
      }
      .width('100%')
    }
  }

  private deviceIndexOf(type: DeviceType): number {
    const metas: DeviceMeta[] = getDeviceMetas();
    for (let i = 0; i < metas.length; i++) {
      if (metas[i].type === type) {
        return i;
      }
    }
    return 0;
  }

  build() {
    Column() {
      // 顶部栏
      Row({ space: 12 }) {
        Text('返回')
          .fontSize(14)
          .fontColor('#2563EB')
          .onClick(() => {
            router.back();
          })
        Text(this.isEditing ? '编辑规则' : '新建规则')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('保存')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#2563EB')
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .borderRadius(14)
          .onClick(() => {
            this.save();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .backgroundColor('#FFFFFF')

      Scroll() {
        Column({ space: 14 }) {
          // 基本信息
          Column({ space: 10 }) {
            this.sectionTitle('规则名称', '')
            TextInput({ text: this.rule.name, placeholder: '例如：高温开空调' })
              .fontSize(14)
              .backgroundColor('#F9FAFB')
              .onChange((value: string) => {
                this.rule.name = value;
              })

            Row() {
              Text('优先级')
                .fontSize(13)
                .fontColor('#374151')
              Blank()
              Text(`P${this.rule.priority}（数字越小越优先）`)
                .fontSize(11)
                .fontColor('#6B7280')
            }
            .width('100%')

            Slider({ value: this.rule.priority, min: 1, max: 9, step: 1, style: SliderStyle.OutSet })
              .width('100%')
              .selectedColor('#2563EB')
              .onChange((value: number) => {
                this.rule.priority = Math.round(value);
                this.touch();
              })
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(14)

          // 条件
          Column({ space: 10 }) {
            this.sectionTitle('触发条件', `已配置 ${this.rule.conditions.length} / 2`)
            ForEach(this.rule.conditions, (condition: RuleCondition, index: number) => {
              this.conditionCard(condition, index)
            }, (condition: RuleCondition, index: number) => `c_${index}_${condition.field}_${condition.op}_${condition.value}`)

            if (this.rule.conditions.length < 2) {
              Text('+ 添加第二个条件（多条件规则）')
                .fontSize(12)
                .fontColor('#2563EB')
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 6, bottom: 6 })
                .onClick(() => {
                  this.addCondition();
                })
            }

            if (this.rule.conditions.length >= 2) {
              Row({ space: 8 }) {
                Text('两个条件的关系')
                  .fontSize(12)
                  .fontColor('#374151')
                Blank()
                ForEach([LogicOp.AND, LogicOp.OR], (op: LogicOp) => {
                  Text(op === LogicOp.AND ? '同时满足(且)' : '任一满足(或)')
                    .fontSize(12)
                    .fontColor(this.rule.logic === op ? '#FFFFFF' : '#4B5563')
                    .backgroundColor(this.rule.logic === op ? '#7C3AED' : '#F3F4F6')
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .borderRadius(8)
                    .onClick(() => {
                      this.rule.logic = op;
                      this.touch();
                    })
                }, (op: LogicOp) => op)
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(14)

          // 动作
          Column({ space: 10 }) {
            this.sectionTitle('设备动作', `已配置 ${this.rule.actions.length} / 3`)
            ForEach(this.rule.actions, (action: RuleAction, index: number) => {
              this.actionCard(action, index)
            }, (action: RuleAction, index: number) => `a_${index}_${action.device}_${action.property}_${action.value}`)

            if (this.rule.actions.length < 3) {
              Text('+ 添加设备动作')
                .fontSize(12)
                .fontColor('#0D9488')
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 6, bottom: 6 })
                .onClick(() => {
                  this.addAction();
                })
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(14)

          if (this.isEditing) {
            Text('删除这条规则')
              .fontSize(14)
              .fontColor('#DC2626')
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(14)
              .backgroundColor('#FFFFFF')
              .borderRadius(14)
              .onClick(() => {
                this.remove();
              })
          }

          Blank().height(30)
        }
        .padding({ left: 16, right: 16, top: 12 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F4F6')
  }
}
