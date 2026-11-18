/**
 * 规则列表：规则卡片、启停开关、冲突提示、新增入口。
 */

import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AutomationRule, LogicOp, priorityLabel } from '../model/RuleModel';
import { ConflictHint, RuleEngine } from '../engine/RuleEngine';
import { AppStore } from '../service/AppStore';
import { actionSummary } from '../common/Formatter';

@Component
export struct RuleListView {
  @Prop @Watch('onVersionChange') dataVersion: number = 0;
  @State rules: AutomationRule[] = [];
  @State hints: string[] = [];
  @State conflictCount: number = 0;

  aboutToAppear(): void {
    this.reload();
  }

  onVersionChange(): void {
    this.reload();
  }

  reload(): void {
    const store: AppStore = AppStore.getInstance();
    const list: AutomationRule[] = [];
    for (let i = 0; i < store.rules.length; i++) {
      list.push(store.rules[i]);
    }
    this.rules = list;

    const found: ConflictHint[] = RuleEngine.detectConflictHints(store.rules);
    const messages: string[] = [];
    for (let i = 0; i < found.length; i++) {
      messages.push(found[i].message);
    }
    this.hints = messages;
    this.conflictCount = found.length;
  }

  async toggleRule(rule: AutomationRule, value: boolean): Promise<void> {
    rule.enabled = value;
    await AppStore.getInstance().persistRules();
    this.reload();
    promptAction.showToast({ message: value ? `已启用「${rule.name}」` : `已停用「${rule.name}」` });
  }

  private openEditor(ruleId: string): void {
    router.pushUrl({
      url: 'pages/RuleEditPage',
      params: { ruleId: ruleId }
    });
  }

  @Builder
  ruleCard(rule: AutomationRule) {
    Column({ space: 8 }) {
      Row() {
        Text(rule.name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(rule.enabled ? '#111827' : '#9CA3AF')
          .layoutWeight(1)
        Text(`P${rule.priority}`)
          .fontSize(11)
          .fontColor('#2563EB')
          .backgroundColor('#EFF6FF')
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(6)
        Toggle({ type: ToggleType.Switch, isOn: rule.enabled })
          .width(44)
          .height(24)
          .margin({ left: 8 })
          .onChange((value: boolean) => {
            this.toggleRule(rule, value);
          })
      }
      .width('100%')

      Row({ space: 6 }) {
        Text('当')
          .fontSize(12)
          .fontColor('#9CA3AF')
        Text(RuleEngine.conditionSummary(rule))
          .fontSize(12)
          .fontColor('#4B5563')
          .layoutWeight(1)
        if (rule.conditions.length >= 2) {
          Text(rule.logic === LogicOp.AND ? '与' : '或')
            .fontSize(11)
            .fontColor('#7C3AED')
            .backgroundColor('#F5F3FF')
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            .borderRadius(4)
        }
      }
      .width('100%')

      Row({ space: 6 }) {
        Text('则')
          .fontSize(12)
          .fontColor('#9CA3AF')
        Text(actionSummary(rule))
          .fontSize(12)
          .fontColor('#0D9488')
          .layoutWeight(1)
        Text('编辑')
          .fontSize(12)
          .fontColor('#2563EB')
          .onClick(() => {
            this.openEditor(rule.id);
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
    .opacity(rule.enabled ? 1 : 0.6)
  }

  build() {
    Column() {
      Row() {
        Column({ space: 2 }) {
          Text('自动化规则')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
          Text('满足条件时自动控制设备')
            .fontSize(12)
            .fontColor('#6B7280')
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text('新增')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#2563EB')
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .borderRadius(16)
          .onClick(() => {
            this.openEditor('new');
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      if (this.conflictCount > 0) {
        Column({ space: 4 }) {
          Row({ space: 6 }) {
            Text('潜在冲突')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#B45309')
            Text(`${this.conflictCount} 处`)
              .fontSize(11)
              .fontColor('#D97706')
          }
          ForEach(this.hints, (message: string) => {
            Text(message)
              .fontSize(11)
              .fontColor('#92400E')
              .width('100%')
          }, (message: string) => message)
        }
        .width('100%')
        .padding(10)
        .margin({ left: 16, right: 16, bottom: 8 })
        .backgroundColor('#FFFBEB')
        .borderRadius(10)
        .alignItems(HorizontalAlign.Start)
      }

      List({ space: 10 }) {
        ForEach(this.rules, (rule: AutomationRule) => {
          ListItem() {
            this.ruleCard(rule)
          }
        }, (rule: AutomationRule) => rule.id)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 16, right: 16 })
      .scrollBar(BarState.Off)

      if (this.rules.length === 0) {
        Text('还没有规则，点右上角「新增」创建第一条')
          .fontSize(13)
          .fontColor('#9CA3AF')
          .padding(20)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F4F6')
  }
}
