/**
 * 设备端冒烟测试：验证应用能在真机 / 模拟器上拉起 EntryAbility。
 *
 * 说明：规则引擎的 12 条业务用例位于 entry/src/test/RuleEngine.test.ets，
 * 属于本地单元测试，不依赖设备；本文件只负责「应用能启动」这层验证。
 */

import { abilityDelegatorRegistry } from '@kit.TestKit';
import { Want } from '@kit.AbilityKit';
import { describe, expect, it } from '@ohos/hypium';

const delegator = abilityDelegatorRegistry.getAbilityDelegator();
const bundleName: string = abilityDelegatorRegistry.getArguments().bundleName;

export default function abilityTest() {
  describe('EntryAbilityTest', () => {
    it('start_entry_ability', 0, async (done: Function) => {
      const want: Want = {
        bundleName: bundleName,
        abilityName: 'EntryAbility'
      };
      await delegator.startAbility(want);
      const topAbility = await delegator.getCurrentTopAbility();
      expect(topAbility.context.abilityInfo.name).assertEqual('EntryAbility');
      done();
    });
  });
}
