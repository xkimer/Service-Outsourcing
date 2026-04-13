import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import hilog from '@ohos.hilog';
import UIAbility from '@ohos.app.ability.UIAbility';
import Want from '@ohos.app.ability.Want';
import window from '@ohos.window';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl'; // 1. 导入权限模块


const DOMAIN = 0x0000;



export default class EntryAbility extends UIAbility {

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {

    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');

  }



  onDestroy(): void {

    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');

  }



  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', 'Ability onWindowStageCreate');

    // 2. 定义需要申请的权限列表（相机和联网）
    const permissions: Array<Permissions> = ['ohos.permission.CAMERA'];

    // 3. 获取权限管理器并申请
    const atManager = abilityAccessCtrl.createAtManager();

    // 弹窗向用户请求权限
    atManager.requestPermissionsFromUser(this.context, permissions).then((data) => {
      // authResults 中，0 代表用户点击了“允许”
      if (data.authResults[0] === 0) {
        hilog.info(DOMAIN, 'SensorCameraSystem', '✅ 用户已授权相机权限');

        // 4. 只有授权成功，才启动硬件逻辑
        try {
          hilog.info(DOMAIN, 'SensorCameraSystem', '🚀 硬件监控逻辑已点火启动！');
        } catch (e) {
          hilog.error(DOMAIN, 'SensorCameraSystem', '❌ 启动硬件逻辑失败: ' + JSON.stringify(e));
        }
      } else {
        hilog.error(DOMAIN, 'SensorCameraSystem', '❌ 用户拒绝了相机授权，功能将无法使用');
      }
    }).catch((err: Error) => {
      hilog.error(DOMAIN, 'SensorCameraSystem', '🚨 权限申请过程发生异常: ' + JSON.stringify(err));
    });

    // 加载页面
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {

    // Main window is destroyed, release UI related resources

    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');

  }



  onForeground(): void {

    // Ability has brought to foreground

    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');

  }



  onBackground(): void {

    // Ability has back to background

    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');

  }

}