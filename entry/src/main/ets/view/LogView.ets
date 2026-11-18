/**
 * 执行日志页：历史演练记录，可展开查看触发顺序、设备变化与冲突裁决。
 */

import { promptAction } from '@kit.ArkUI';
import { formatPropertyValue } from '../model/DeviceModel';
import { ConflictRecord, DeviceChange, ExecutionResult, RuleHit, SkippedRule } from '../model/LogModel';
import { AppStore } from '../service/AppStore';
import { formatTime } from '../common/Utils';

@Component
export struct LogView {
  @Prop @Watch('onVersionChange') dataVersion: number = 0;
  @State logs: ExecutionResult[] = [];
  @State expandedId: string = '';

  aboutToAppear(): void {
    this.reload();
  }

  onVersionChange(): void {
    this.reload();
  }

  reload(): void {
    const store: AppStore = AppStore.getInstance();
    const list: ExecutionResult[] = [];
    // 最新的排在最前面
    for (let i = store.logs.length - 1; i >= 0; i--) {
      list.push(store.logs[i]);
    }
    this.logs = list;
  }

  private async clearAll(): Promise<void> {
    promptAction.showDialog({
      title: '清空执行记录',
      message: '将删除全部演练历史（规则与设备状态保留），确定继续吗？',
      buttons: [
        { text: '取消', color: '#6B7280' },
        { text: '清空', color: '#DC2626' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        const store: AppStore = AppStore.getInstance();
        store.logs = [];
        store.persistLogs();
        this.reload();
        promptAction.showToast({ message: '记录已清空' });
      }
    });
  }

  @Builder
  detailBlock(log: ExecutionResult) {
    Column({ space: 10 }) {
      // 触发顺序
      Column({ space: 4 }) {
        Text('规则执行顺序')
          .fontSize(11)
          .fontColor('#2563EB')
          .width('100%')
        if (log.hits.length === 0) {
          Text('本次没有规则被触发')
            .fontSize(11)
            .fontColor('#9CA3AF')
            .width('100%')
        }
        ForEach(log.hits, (hit: RuleHit) => {
          Row({ space: 6 }) {
            Text(`${hit.order}`)
              .fontSize(10)
              .fontColor('#FFFFFF')
              .backgroundColor('#2563EB')
              .width(16)
              .height(16)
              .textAlign(TextAlign.Center)
              .borderRadius(8)
            Text(hit.ruleName)
              .fontSize(12)
              .fontColor('#111827')
              .layoutWeight(1)
            Text(`P${hit.priority}`)
              .fontSize(10)
              .fontColor('#6B7280')
          }
          .width('100%')

          Text(hit.conditionSummary)
            .fontSize(10)
            .fontColor('#9CA3AF')
            .width('100%')
            .padding({ left: 22 })
        }, (hit: RuleHit) => `h_${hit.ruleId}_${hit.order}`)
      }
      .width('100%')

      // 设备变化
      Column({ space: 3 }) {
        Text('设备变化')
          .fontSize(11)
          .fontColor('#0D9488')
          .width('100%')
        if (log.changes.length === 0) {
          Text('设备状态无变化')
            .fontSize(11)
            .fontColor('#9CA3AF')
            .width('100%')
        }
        ForEach(log.changes, (change: DeviceChange, index: number) => {
          Row() {
            Text(change.deviceName)
              .fontSize(11)
              .fontColor('#4B5563')
              .width(56)
            Text(`${formatPropertyValue(change.property, change.fromValue)} → ${formatPropertyValue(change.property, change.toValue)}`)
              .fontSize(11)
              .fontColor('#111827')
              .layoutWeight(1)
            Text(change.ruleName)
              .fontSize(10)
              .fontColor('#9CA3AF')
          }
          .width('100%')
        }, (change: DeviceChange, index: number) => `c_${index}`)
      }
      .width('100%')

      // 冲突
      if (log.conflicts.length > 0) {
        Column({ space: 4 }) {
          Text(`冲突裁决（${log.conflicts.length}）`)
            .fontSize(11)
            .fontColor('#B45309')
            .width('100%')
          ForEach(log.conflicts, (conflict: ConflictRecord, index: number) => {
            Text(conflict.reason)
              .fontSize(10)
              .fontColor('#92400E')
              .width('100%')
              .padding(6)
              .backgroundColor('#FFFBEB')
              .borderRadius(6)
          }, (conflict: ConflictRecord, index: number) => `cf_${index}`)
        }
        .width('100%')
      }

      // 跳过
      if (log.skipped.length > 0) {
        Column({ space: 2 }) {
          Text(`未执行规则（${log.skipped.length}）`)
            .fontSize(11)
            .fontColor('#6B7280')
            .width('100%')
          ForEach(log.skipped, (skipped: SkippedRule, index: number) => {
            Row() {
              Text(skipped.ruleName)
                .fontSize(10)
                .fontColor('#4B5563')
                .layoutWeight(1)
              Text(skipped.reason)
                .fontSize(10)
                .fontColor('#9CA3AF')
            }
            .width('100%')
          }, (skipped: SkippedRule, index: number) => `s_${index}`)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(10)
    .backgroundColor('#F9FAFB')
    .borderRadius(10)
  }

  @Builder
  logCard(log: ExecutionResult, index: number) {
    Column({ space: 8 }) {
      Row() {
        Column({ space: 2 }) {
          Text(log.scenarioName === '' ? '手工调参' : log.scenarioName)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#111827')
          Text(formatTime(log.timestamp))
            .fontSize(11)
            .fontColor('#9CA3AF')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row({ space: 8 }) {
          Text(`触发 ${log.hits.length}`)
            .fontSize(11)
            .fontColor('#2563EB')
          Text(`变化 ${log.changes.length}`)
            .fontSize(11)
            .fontColor('#0D9488')
          if (log.conflicts.length > 0) {
            Text(`冲突 ${log.conflicts.length}`)
              .fontSize(11)
              .fontColor('#DC2626')
          }
        }
      }
      .width('100%')

      Row() {
        Text(`环境：${Math.round(log.env.temperature)}℃ / ${Math.round(log.env.humidity)}% / ${Math.round(log.env.illuminance)}lux / ${log.env.occupancy ? '有人' : '无人'}`)
          .fontSize(10)
          .fontColor('#6B7280')
          .layoutWeight(1)
        Text(this.expandedId === log.id ? '收起' : '详情')
          .fontSize(11)
          .fontColor('#2563EB')
      }
      .width('100%')

      if (this.expandedId === log.id) {
        this.detailBlock(log)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
    .onClick(() => {
      this.expandedId = this.expandedId === log.id ? '' : log.id;
    })
  }

  build() {
    Column() {
      Row() {
        Column({ space: 2 }) {
          Text('执行日志')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
          Text('每一次演练的触发条件、设备变化与执行顺序')
            .fontSize(12)
            .fontColor('#6B7280')
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        if (this.logs.length > 0) {
          Text('清空')
            .fontSize(13)
            .fontColor('#DC2626')
            .onClick(() => {
              this.clearAll();
            })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      if (this.logs.length === 0) {
        Column({ space: 8 }) {
          Text('暂无执行记录')
            .fontSize(14)
            .fontColor('#6B7280')
          Text('到「模拟」页点一次「执行联动」，这里就会留下完整记录')
            .fontSize(12)
            .fontColor('#9CA3AF')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.logs, (log: ExecutionResult, index: number) => {
            ListItem() {
              this.logCard(log, index)
            }
          }, (log: ExecutionResult, index: number) => log.id)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F4F6')
  }
}
