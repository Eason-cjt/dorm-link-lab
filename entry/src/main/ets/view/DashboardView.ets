/**
 * 首页仪表盘：环境快照 + 设备状态 + 最近一次联动结果。
 */

import { deviceLabel, DeviceState, cloneDevice } from '../model/DeviceModel';
import { cloneEnv, EnvData, envFieldLabel, envFieldUnit, formatEnvValue, EnvField, readEnvField } from '../model/EnvModel';
import { ExecutionResult } from '../model/LogModel';
import { AppStore } from '../service/AppStore';
import { deviceStatusText, isDeviceActive } from '../common/Formatter';
import { formatTime } from '../common/Utils';

@Component
export struct DashboardView {
  @Prop @Watch('onVersionChange') dataVersion: number = 0;
  @State env: EnvData = new EnvData();
  @State devices: DeviceState[] = [];
  @State ruleCount: number = 0;
  @State enabledCount: number = 0;
  @State hasLog: boolean = false;
  @State hitCount: number = 0;
  @State changeCount: number = 0;
  @State conflictCount: number = 0;
  @State lastLogTime: string = '';
  @State lastScenario: string = '';

  aboutToAppear(): void {
    this.reload();
  }

  onVersionChange(): void {
    this.reload();
  }

  reload(): void {
    const store: AppStore = AppStore.getInstance();
    this.env = cloneEnv(store.currentEnv);
    const list: DeviceState[] = [];
    for (let i = 0; i < store.devices.length; i++) {
      list.push(cloneDevice(store.devices[i]));
    }
    this.devices = list;
    this.ruleCount = store.rules.length;
    let enabled: number = 0;
    for (let i = 0; i < store.rules.length; i++) {
      if (store.rules[i].enabled) {
        enabled = enabled + 1;
      }
    }
    this.enabledCount = enabled;

    if (store.logs.length > 0) {
      const last: ExecutionResult = store.logs[store.logs.length - 1];
      this.hasLog = true;
      this.hitCount = last.hits.length;
      this.changeCount = last.changes.length;
      this.conflictCount = last.conflicts.length;
      this.lastLogTime = formatTime(last.timestamp);
      this.lastScenario = last.scenarioName === '' ? '手工调参' : last.scenarioName;
    } else {
      this.hasLog = false;
    }
  }

  /**
   * 环境指标块。
   * 注意：@Builder 的参数是「按值传入」的，传入计算好的字符串会导致状态更新后
   * 界面不重算（参数被缓存）。因此这里只传不变的字段枚举，数值在 Builder 内部
   * 直接读 this.env，才能跟随 @State 刷新。
   */
  @Builder
  envChip(field: EnvField) {
    Column({ space: 4 }) {
      Text(envFieldLabel(field))
        .fontSize(12)
        .fontColor('#6B7280')
      Text(formatEnvValue(field, readEnvField(this.env, field)))
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#111827')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 10, bottom: 10 })
  }

  @Builder
  deviceCard(device: DeviceState) {
    Column({ space: 6 }) {
      Row() {
        Text(deviceLabel(device.type))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827')
        Blank()
        Circle({ width: 8, height: 8 })
          .fill(isDeviceActive(device) ? '#16A34A' : '#D1D5DB')
      }
      .width('100%')

      Text(deviceStatusText(device))
        .fontSize(13)
        .fontColor(isDeviceActive(device) ? '#16A34A' : '#9CA3AF')
        .width('100%')
    }
    .width('48%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 4 }) {
          Text('联动实验室')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
          Text('智能宿舍自动化规则编排与联动模拟')
            .fontSize(13)
            .fontColor('#6B7280')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        // 环境快照
        Column({ space: 10 }) {
          Row() {
            Text('当前模拟环境')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#374151')
            Blank()
            Text('在「模拟」页调整')
              .fontSize(12)
              .fontColor('#9CA3AF')
          }
          .width('100%')

          Row() {
            this.envChip(EnvField.TEMPERATURE)
            this.envChip(EnvField.HUMIDITY)
            this.envChip(EnvField.ILLUMINANCE)
            this.envChip(EnvField.OCCUPANCY)
          }
          .width('100%')
        }
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .width('100%')

        // 设备状态
        Column({ space: 10 }) {
          Row() {
            Text('设备状态')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#374151')
            Blank()
            Text(`${this.devices.length} 台`)
              .fontSize(12)
              .fontColor('#9CA3AF')
          }
          .width('100%')

          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
            ForEach(this.devices, (item: DeviceState) => {
              this.deviceCard(item)
            }, (item: DeviceState) => item.type)
          }
          .width('100%')
        }
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .width('100%')

        // 规则概况 + 最近一次执行
        Column({ space: 12 }) {
          Row() {
            Text('规则')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#374151')
            Blank()
            Text(`共 ${this.ruleCount} 条 · 启用 ${this.enabledCount} 条`)
              .fontSize(12)
              .fontColor('#6B7280')
          }
          .width('100%')

          Divider().color('#F3F4F6')

          if (this.hasLog) {
            Row() {
              Text('最近演练')
                .fontSize(13)
                .fontColor('#6B7280')
              Blank()
              Text(`${this.lastScenario} · ${this.lastLogTime}`)
                .fontSize(12)
                .fontColor('#9CA3AF')
            }
            .width('100%')

            Row({ space: 10 }) {
              this.metricBox('触发规则', `${this.hitCount}`, '#2563EB')
              this.metricBox('设备变化', `${this.changeCount}`, '#0D9488')
              this.metricBox('冲突裁决', `${this.conflictCount}`, '#DC2626')
            }
            .width('100%')
          } else {
            Text('还没有演练记录，去「模拟」页套用一个场景试试')
              .fontSize(13)
              .fontColor('#9CA3AF')
              .width('100%')
          }
        }
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .width('100%')

        Blank().height(20)
      }
      .padding({ left: 16, right: 16, top: 12 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F4F6')
    .scrollBar(BarState.Off)
  }

  @Builder
  metricBox(label: string, value: string, color: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(11)
        .fontColor('#6B7280')
    }
    .layoutWeight(1)
    .padding({ top: 8, bottom: 8 })
    .backgroundColor('#F9FAFB')
    .borderRadius(10)
  }
}
