/**
 * 模拟页：套用场景 / 手工调参 → 执行规则引擎 → 观察设备联动与冲突裁决。
 */

import { promptAction } from '@kit.ArkUI';
import { cloneDevice, DeviceState, deviceLabel, formatPropertyValue } from '../model/DeviceModel';
import { EnvData, EnvField, envFieldLabel, formatEnvValue } from '../model/EnvModel';
import { ConflictRecord, DeviceChange, ExecutionResult, RuleHit, SkippedRule } from '../model/LogModel';
import { RuleEngine } from '../engine/RuleEngine';
import { AppStore } from '../service/AppStore';
import { getScenarioPresets, ScenarioPreset } from '../service/ScenarioPresets';

@Component
export struct SimulatorView {
  @Prop @Watch('onVersionChange') dataVersion: number = 0;

  @State temperature: number = 26;
  @State humidity: number = 50;
  @State illuminance: number = 300;
  @State occupancy: boolean = true;

  @State hasResult: boolean = false;
  @State result: ExecutionResult = new ExecutionResult();
  @State showSkipped: boolean = false;

  aboutToAppear(): void {
    this.syncFromStore();
  }

  onVersionChange(): void {
    this.syncFromStore();
  }

  private syncFromStore(): void {
    const store: AppStore = AppStore.getInstance();
    this.temperature = store.currentEnv.temperature;
    this.humidity = store.currentEnv.humidity;
    this.illuminance = store.currentEnv.illuminance;
    this.occupancy = store.currentEnv.occupancy;
  }

  private buildEnv(): EnvData {
    const env: EnvData = new EnvData();
    env.temperature = this.temperature;
    env.humidity = this.humidity;
    env.illuminance = this.illuminance;
    env.occupancy = this.occupancy;
    return env;
  }

  private applyScenario(preset: ScenarioPreset): void {
    this.temperature = preset.env.temperature;
    this.humidity = preset.env.humidity;
    this.illuminance = preset.env.illuminance;
    this.occupancy = preset.env.occupancy;
    const store: AppStore = AppStore.getInstance();
    store.currentEnv = this.buildEnv();
    store.persistEnv();
    promptAction.showToast({ message: `已套用场景：${preset.name}` });
  }

  private async execute(scenarioName: string): Promise<void> {
    const store: AppStore = AppStore.getInstance();
    const env: EnvData = this.buildEnv();
    store.currentEnv = env;

    const outcome: ExecutionResult = RuleEngine.run(store.rules, env, store.devices, scenarioName);

    // 联动结果真正落到设备状态上
    const nextDevices: DeviceState[] = [];
    for (let i = 0; i < outcome.devicesAfter.length; i++) {
      nextDevices.push(cloneDevice(outcome.devicesAfter[i]));
    }
    store.devices = nextDevices;
    store.addLog(outcome);

    await store.persistDevices();
    await store.persistLogs();
    await store.persistEnv();

    this.result = outcome;
    this.hasResult = true;
    this.showSkipped = false;
    promptAction.showToast({
      message: `触发 ${outcome.hits.length} 条规则，${outcome.changes.length} 项设备变化`
    });
  }

  @Builder
  envSlider(label: string, unit: string, value: number, min: number, max: number, step: number,
    onChange: (value: number) => void) {
    Column({ space: 4 }) {
      Row() {
        Text(label)
          .fontSize(13)
          .fontColor('#374151')
        Blank()
        Text(`${Math.round(value)}${unit}`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827')
      }
      .width('100%')

      Slider({ value: value, min: min, max: max, step: step, style: SliderStyle.OutSet })
        .width('100%')
        .selectedColor('#2563EB')
        .onChange((current: number) => {
          onChange(Math.round(current));
        })
    }
    .width('100%')
  }

  @Builder
  hitRow(hit: RuleHit) {
    Row({ space: 8 }) {
      Text(`${hit.order}`)
        .fontSize(11)
        .fontColor('#FFFFFF')
        .backgroundColor('#2563EB')
        .width(18)
        .height(18)
        .textAlign(TextAlign.Center)
        .borderRadius(9)
      Column({ space: 2 }) {
        Row({ space: 6 }) {
          Text(hit.ruleName)
            .fontSize(13)
            .fontColor('#111827')
          Text(`P${hit.priority}`)
            .fontSize(10)
            .fontColor('#6B7280')
            .backgroundColor('#F3F4F6')
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .borderRadius(4)
        }
        Text(hit.conditionSummary)
          .fontSize(11)
          .fontColor('#6B7280')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 5, bottom: 5 })
  }

  @Builder
  changeRow(change: DeviceChange) {
    Row() {
      Text(change.deviceName)
        .fontSize(12)
        .fontColor('#374151')
        .width(60)
      Text(`${formatPropertyValue(change.property, change.fromValue)} → ${formatPropertyValue(change.property, change.toValue)}`)
        .fontSize(12)
        .fontColor(change.toValue > change.fromValue ? '#16A34A' : '#DC2626')
        .layoutWeight(1)
      Text(change.ruleName)
        .fontSize(10)
        .fontColor('#9CA3AF')
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
  }

  @Builder
  conflictRow(conflict: ConflictRecord) {
    Column({ space: 2 }) {
      Text(`${conflict.deviceName} · ${formatPropertyValue(conflict.property, conflict.winnerValue)} 生效`)
        .fontSize(12)
        .fontColor('#B45309')
        .width('100%')
      Text(conflict.reason)
        .fontSize(11)
        .fontColor('#92400E')
        .width('100%')
    }
    .width('100%')
    .padding(8)
    .backgroundColor('#FFFBEB')
    .borderRadius(8)
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Column({ space: 2 }) {
          Text('模拟演练')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
          Text('调整环境数据，观察规则如何驱动设备')
            .fontSize(12)
            .fontColor('#6B7280')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        // 场景预设
        Column({ space: 10 }) {
          Text('环境场景')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#374151')
            .width('100%')

          Row({ space: 10 }) {
            ForEach(getScenarioPresets(), (preset: ScenarioPreset) => {
              Column({ space: 4 }) {
                Text(preset.name)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#2563EB')
                Text(preset.description)
                  .fontSize(10)
                  .fontColor('#6B7280')
                  .textAlign(TextAlign.Center)
              }
              .layoutWeight(1)
              .padding(10)
              .backgroundColor('#EFF6FF')
              .borderRadius(10)
              .onClick(() => {
                this.applyScenario(preset);
              })
            }, (preset: ScenarioPreset) => preset.name)
          }
          .width('100%')
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(14)

        // 环境参数
        Column({ space: 14 }) {
          Text('模拟环境参数')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#374151')
            .width('100%')

          this.envSlider(envFieldLabel(EnvField.TEMPERATURE), '℃', this.temperature, 10, 40, 1,
            (value: number) => {
              this.temperature = value;
            })
          this.envSlider(envFieldLabel(EnvField.HUMIDITY), '%', this.humidity, 10, 95, 1,
            (value: number) => {
              this.humidity = value;
            })
          this.envSlider(envFieldLabel(EnvField.ILLUMINANCE), 'lux', this.illuminance, 0, 2000, 50,
            (value: number) => {
              this.illuminance = value;
            })

          Row() {
            Text(envFieldLabel(EnvField.OCCUPANCY))
              .fontSize(13)
              .fontColor('#374151')
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.occupancy })
              .width(44)
              .height(24)
              .onChange((value: boolean) => {
                this.occupancy = value;
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(14)

        Button('执行联动')
          .width('100%')
          .height(44)
          .fontSize(15)
          .backgroundColor('#2563EB')
          .onClick(() => {
            this.execute('手工调参');
          })

        // 执行结果
        if (this.hasResult) {
          Column({ space: 12 }) {
            Row() {
              Text('执行结果')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#374151')
              Blank()
              Text(this.result.scenarioName === '' ? '手工调参' : this.result.scenarioName)
                .fontSize(11)
                .fontColor('#6B7280')
            }
            .width('100%')

            // 触发规则（执行顺序）
            Column({ space: 4 }) {
              Text(`触发规则 · 按执行顺序（${this.result.hits.length}）`)
                .fontSize(12)
                .fontColor('#2563EB')
                .width('100%')
              ForEach(this.result.hits, (hit: RuleHit) => {
                this.hitRow(hit)
              }, (hit: RuleHit) => `hit_${hit.ruleId}_${hit.order}`)
              if (this.result.hits.length === 0) {
                Text('没有规则被触发')
                  .fontSize(12)
                  .fontColor('#9CA3AF')
                  .width('100%')
              }
            }
            .width('100%')
            .padding(10)
            .backgroundColor('#F9FAFB')
            .borderRadius(10)

            // 设备变化
            Column({ space: 4 }) {
              Text(`设备变化（${this.result.changes.length}）`)
                .fontSize(12)
                .fontColor('#0D9488')
                .width('100%')
              ForEach(this.result.changes, (change: DeviceChange, index: number) => {
                this.changeRow(change)
              }, (change: DeviceChange, index: number) => `chg_${index}`)
              if (this.result.changes.length === 0) {
                Text('设备状态无需改变')
                  .fontSize(12)
                  .fontColor('#9CA3AF')
                  .width('100%')
              }
            }
            .width('100%')
            .padding(10)
            .backgroundColor('#F9FAFB')
            .borderRadius(10)

            // 冲突
            if (this.result.conflicts.length > 0) {
              Column({ space: 6 }) {
                Text(`冲突裁决（${this.result.conflicts.length}）`)
                  .fontSize(12)
                  .fontColor('#B45309')
                  .width('100%')
                ForEach(this.result.conflicts, (conflict: ConflictRecord, index: number) => {
                  this.conflictRow(conflict)
                }, (conflict: ConflictRecord, index: number) => `cf_${index}`)
              }
              .width('100%')
            }

            // 未执行规则
            Row() {
              Text(`未执行规则（${this.result.skipped.length}）`)
                .fontSize(12)
                .fontColor('#6B7280')
              Blank()
              Text(this.showSkipped ? '收起' : '展开')
                .fontSize(11)
                .fontColor('#2563EB')
                .onClick(() => {
                  this.showSkipped = !this.showSkipped;
                })
            }
            .width('100%')

            if (this.showSkipped) {
              Column({ space: 3 }) {
                ForEach(this.result.skipped, (skipped: SkippedRule, index: number) => {
                  Row() {
                    Text(skipped.ruleName)
                      .fontSize(12)
                      .fontColor('#4B5563')
                      .layoutWeight(1)
                    Text(skipped.reason)
                      .fontSize(11)
                      .fontColor('#9CA3AF')
                  }
                  .width('100%')
                }, (skipped: SkippedRule, index: number) => `sk_${index}`)
              }
              .width('100%')
              .padding(10)
              .backgroundColor('#F9FAFB')
              .borderRadius(10)
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(14)
        }

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
}
