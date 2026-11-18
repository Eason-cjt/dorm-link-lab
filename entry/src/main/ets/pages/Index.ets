import { common } from '@kit.AbilityKit';
import { AppStore } from '../service/AppStore';
import { DashboardView } from '../view/DashboardView';
import { RuleListView } from '../view/RuleListView';
import { SimulatorView } from '../view/SimulatorView';
import { LogView } from '../view/LogView';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  /** 数据版本号：任何页面改动数据后 +1，各子页面通过 @Watch 刷新 */
  @State dataVersion: number = 0;

  aboutToAppear(): void {
    this.loadStore();
  }

  onPageShow(): void {
    // 从规则编辑页返回时触发，让列表与首页拿到最新数据
    this.dataVersion = this.dataVersion + 1;
  }

  private async loadStore(): Promise<void> {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await AppStore.getInstance().ensureLoaded(context);
    this.dataVersion = this.dataVersion + 1;
  }

  @Builder
  tabBarItem(title: string, index: number) {
    Column({ space: 3 }) {
      Text(title)
        .fontSize(12)
        .fontColor(this.currentIndex === index ? '#2563EB' : '#9CA3AF')
        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Normal)
    }
    .width('100%')
    .height(50)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        DashboardView({ dataVersion: this.dataVersion })
      }
      .tabBar(this.tabBarItem('首页', 0))

      TabContent() {
        RuleListView({ dataVersion: this.dataVersion })
      }
      .tabBar(this.tabBarItem('规则', 1))

      TabContent() {
        SimulatorView({ dataVersion: this.dataVersion })
      }
      .tabBar(this.tabBarItem('模拟', 2))

      TabContent() {
        LogView({ dataVersion: this.dataVersion })
      }
      .tabBar(this.tabBarItem('日志', 3))
    }
    .barHeight(54)
    .barMode(BarMode.Fixed)
    .scrollable(false)
    .divider({ strokeWidth: 0.5, color: '#E5E7EB' })
    .onChange((index: number) => {
      this.currentIndex = index;
      this.dataVersion = this.dataVersion + 1;
    })
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F4F6')
  }
}
