/**
 * 应用内存状态容器
 *
 * 页面之间不直接互相传对象，统一从这里取数据；
 * 每次修改后调用对应的 persistXxx 落盘，保证「关闭进程再打开还能恢复」。
 */

import { common } from '@kit.AbilityKit';
import { createDefaultDevices, DeviceState } from '../model/DeviceModel';
import { EnvData } from '../model/EnvModel';
import { AutomationRule } from '../model/RuleModel';
import { ExecutionResult } from '../model/LogModel';
import { StorageService } from './StorageService';
import { createDefaultRules, getScenarioPresets } from './ScenarioPresets';

export class AppStore {
  private static instance: AppStore = new AppStore();

  rules: AutomationRule[] = [];
  devices: DeviceState[] = [];
  logs: ExecutionResult[] = [];
  currentEnv: EnvData = new EnvData();

  private loaded: boolean = false;

  static getInstance(): AppStore {
    return AppStore.instance;
  }

  /** 首次进入时从 Preferences 恢复；无历史数据则灌入默认规则与设备 */
  async ensureLoaded(context: common.Context): Promise<void> {
    if (this.loaded) {
      return;
    }
    await StorageService.init(context);
    if (!StorageService.isReady()) {
      // 存储不可用时退化为纯内存模式，界面仍可操作
      this.rules = createDefaultRules();
      this.devices = createDefaultDevices();
      this.currentEnv = getScenarioPresets()[0].env;
      this.loaded = true;
      return;
    }

    const storedRules: AutomationRule[] = await StorageService.loadRules();
    if (storedRules.length > 0) {
      this.rules = storedRules;
    } else {
      this.rules = createDefaultRules();
      await StorageService.saveRules(this.rules);
    }

    const storedDevices: DeviceState[] = await StorageService.loadDevices();
    if (storedDevices.length > 0) {
      this.devices = storedDevices;
    } else {
      this.devices = createDefaultDevices();
      await StorageService.saveDevices(this.devices);
    }

    this.logs = await StorageService.loadLogs();

    const storedEnv: EnvData | undefined = await StorageService.loadEnv();
    this.currentEnv = storedEnv !== undefined ? storedEnv : getScenarioPresets()[0].env;

    this.loaded = true;
  }

  isLoaded(): boolean {
    return this.loaded;
  }

  async persistRules(): Promise<void> {
    await StorageService.saveRules(this.rules);
  }

  async persistDevices(): Promise<void> {
    await StorageService.saveDevices(this.devices);
  }

  async persistLogs(): Promise<void> {
    await StorageService.saveLogs(this.logs);
  }

  async persistEnv(): Promise<void> {
    await StorageService.saveEnv(this.currentEnv);
  }

  /** 按 id 取规则下标，找不到返回 -1 */
  indexOfRule(ruleId: string): number {
    for (let i = 0; i < this.rules.length; i++) {
      if (this.rules[i].id === ruleId) {
        return i;
      }
    }
    return -1;
  }

  /** 追加一条执行记录，内存中最多保留 20 条 */
  addLog(result: ExecutionResult): void {
    this.logs.push(result);
    if (this.logs.length > 20) {
      this.logs.splice(0, this.logs.length - 20);
    }
  }
}
