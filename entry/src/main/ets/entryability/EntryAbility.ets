import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

/**
 * 猫狗分类 App 入口 Ability
 */
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.info('[PetSnap] EntryAbility onCreate');
  }

  onDestroy(): void {
    console.info('[PetSnap] EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    console.info('[PetSnap] EntryAbility onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        console.error(`[PetSnap] 加载页面失败: ${JSON.stringify(err)}`);
        return;
      }
      console.info('[PetSnap] 页面加载成功');
    });
  }

  onWindowStageDestroy(): void {
    console.info('[PetSnap] EntryAbility onWindowStageDestroy');
  }

  onForeground(): void {
    console.info('[PetSnap] EntryAbility onForeground');
  }

  onBackground(): void {
    console.info('[PetSnap] EntryAbility onBackground');
  }
}
