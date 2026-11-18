/**
 * 本地持久化服务（基于 Preferences）
 *
 * 选型说明：本应用的数据全部是「整体读写、无复杂查询」的结构，
 * 规则总数在个位数、日志只保留最近若干条，Preferences 的键值模型完全够用，
 * 且 API 简单、无需建表。若后续要做「按设备 / 按时间检索历史记录」，
 * 应换用 RDB（关系型数据库）——这一点写在报告的「技术局限」里。
 *
 * 注意：Preferences 单个 value 有长度上限（约 8KB），因此日志只保留最近 8 条，
 * 且持久化前剥离体积最大的 devicesAfter 快照。
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { DeviceState } from '../model/DeviceModel';
import { EnvData } from '../model/EnvModel';
import { AutomationRule } from '../model/RuleModel';
import { ExecutionResult } from '../model/LogModel';

const STORE_NAME: string = 'dorm_link_lab_store';
const KEY_RULES: string = 'rules';
const KEY_DEVICES: string = 'devices';
const KEY_LOGS: string = 'logs';
const KEY_ENV: string = 'env';
/** 日志保留条数，控制单值体积 */
const MAX_LOG_KEEP: number = 8;

export class StorageService {
  private static store: preferences.Preferences | undefined = undefined;

  /** 初始化，重复调用安全 */
  static async init(context: common.Context): Promise<void> {
    if (StorageService.store !== undefined) {
      return;
    }
    StorageService.store = await preferences.getPreferences(context, STORE_NAME);
  }

  static isReady(): boolean {
    return StorageService.store !== undefined;
  }

  private static async writeRaw(key: string, value: string): Promise<void> {
    const store: preferences.Preferences | undefined = StorageService.store;
    if (store === undefined) {
      return;
    }
    await store.put(key, value);
    await store.flush();
  }

  private static async readRaw(key: string): Promise<string> {
    const store: preferences.Preferences | undefined = StorageService.store;
    if (store === undefined) {
      return '';
    }
    const value: preferences.ValueType = await store.get(key, '');
    return value as string;
  }

  static async saveRules(rules: AutomationRule[]): Promise<void> {
    await StorageService.writeRaw(KEY_RULES, JSON.stringify(rules));
  }

  /** 读取规则；无数据时返回空数组，由调用方决定是否灌入默认规则 */
  static async loadRules(): Promise<AutomationRule[]> {
    const raw: string = await StorageService.readRaw(KEY_RULES);
    if (raw === '') {
      return [];
    }
    const list: AutomationRule[] = JSON.parse(raw) as AutomationRule[];
    for (let i = 0; i < list.length; i++) {
      if (list[i].conditions === undefined) {
        list[i].conditions = [];
      }
      if (list[i].actions === undefined) {
        list[i].actions = [];
      }
    }
    return list;
  }

  static async saveDevices(devices: DeviceState[]): Promise<void> {
    await StorageService.writeRaw(KEY_DEVICES, JSON.stringify(devices));
  }

  static async loadDevices(): Promise<DeviceState[]> {
    const raw: string = await StorageService.readRaw(KEY_DEVICES);
    if (raw === '') {
      return [];
    }
    return JSON.parse(raw) as DeviceState[];
  }

  static async saveEnv(env: EnvData): Promise<void> {
    await StorageService.writeRaw(KEY_ENV, JSON.stringify(env));
  }

  static async loadEnv(): Promise<EnvData | undefined> {
    const raw: string = await StorageService.readRaw(KEY_ENV);
    if (raw === '') {
      return undefined;
    }
    return JSON.parse(raw) as EnvData;
  }

  /** 保存执行记录，自动截断条数并剥离大字段 */
  static async saveLogs(logs: ExecutionResult[]): Promise<void> {
    const trimmed: ExecutionResult[] = [];
    const start: number = logs.length > MAX_LOG_KEEP ? logs.length - MAX_LOG_KEEP : 0;
    for (let i = start; i < logs.length; i++) {
      const item: ExecutionResult = logs[i];
      const copy: ExecutionResult = new ExecutionResult();
      copy.id = item.id;
      copy.timestamp = item.timestamp;
      copy.scenarioName = item.scenarioName;
      copy.env = item.env;
      copy.hits = item.hits;
      copy.changes = item.changes;
      copy.conflicts = item.conflicts;
      copy.skipped = item.skipped;
      copy.devicesAfter = [];
      trimmed.push(copy);
    }
    await StorageService.writeRaw(KEY_LOGS, JSON.stringify(trimmed));
  }

  static async loadLogs(): Promise<ExecutionResult[]> {
    const raw: string = await StorageService.readRaw(KEY_LOGS);
    if (raw === '') {
      return [];
    }
    const list: ExecutionResult[] = JSON.parse(raw) as ExecutionResult[];
    for (let i = 0; i < list.length; i++) {
      if (list[i].hits === undefined) {
        list[i].hits = [];
      }
      if (list[i].changes === undefined) {
        list[i].changes = [];
      }
      if (list[i].conflicts === undefined) {
        list[i].conflicts = [];
      }
      if (list[i].skipped === undefined) {
        list[i].skipped = [];
      }
      if (list[i].devicesAfter === undefined) {
        list[i].devicesAfter = [];
      }
    }
    return list;
  }

  /** 清空所有数据，用于「重开」演示 */
  static async clearAll(): Promise<void> {
    await StorageService.writeRaw(KEY_RULES, '');
    await StorageService.writeRaw(KEY_DEVICES, '');
    await StorageService.writeRaw(KEY_LOGS, '');
    await StorageService.writeRaw(KEY_ENV, '');
  }
}
