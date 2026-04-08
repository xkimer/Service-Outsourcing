import router from '@ohos.router';
import { apiGet, apiPost } from '../common/Api';

interface PresetModel {
  name: string;
  model: string;
  standardLabel: string;
  enabled: boolean;
}

interface CameraConfig {
  exposure: number;
  resolution: string;
}

interface ConfigData {
  models: PresetModel[];
  positionTolerance: number;
  sensitivity: string;
  lightCompensation: number;
  camera: CameraConfig;
}

@Component
struct LiveValueText {
  @Prop value: string; // 使用 @Prop 强制监听父组件的变化

  build() {
    Text(this.value)
      .fontSize(14)
      .fontWeight(FontWeight.Bold)
      .fontColor('#3B82F6')
  }
}

@Entry
@Component
struct Settings {
  @State presetModels: PresetModel[] = [{
    name: '冰箱',
    model: 'BCD-520W',
    standardLabel: 'A++',
    enabled: true
  }];
  @State newName: string = '';
  @State newModel: string = '';
  @State newLabel: string = 'A++';
  // 下拉菜单选项
  private labelOptions: SelectOption[] = [
    { value: 'A++' }, { value: 'A+' }, { value: 'A' }, { value: 'B' }, { value: 'C' }
  ];
  @State positionTolerance: number = 10;
  @State sensitivity: string = '中';
  @State lightCompensation: number = 0;
  @State exposure: number = 0;
  @State resolution: string = '1280x720';
  @State isSaving: boolean = false;
  private sensitivityLevels: string[] = ['低', '中', '高'];
  private resolutions: string[] = ['640x480', '1280x720', '1920x1080'];

  aboutToAppear() {
    this.fetchConfig();
  }

  // 添加新产品型号
  addModel() {
    if (this.newName.trim() === '' || this.newModel.trim() === '') {
      AlertDialog.show({ message: '请输入完整的产品名称和型号' });
      return;
    }
    this.presetModels.push({
      name: this.newName,
      model: this.newModel,
      standardLabel: this.newLabel,
      enabled: true
    });
    // 重置输入状态
    this.newName = '';
    this.newModel = '';
  }

  async fetchConfig() {
    try {
      let d = await apiGet('/api/config') as ConfigData;
      if (d.models) this.presetModels = d.models;
      this.positionTolerance = d.positionTolerance ?? 10;
      this.sensitivity = d.sensitivity ?? '中';
      this.lightCompensation = d.lightCompensation ?? 0;
      this.exposure = d.camera?.exposure ?? 0;
      this.resolution = d.camera?.resolution ?? '1280x720';
    } catch (e) {
    }
  }

  async saveConfig() {
    this.isSaving = true;
    let cfg: ConfigData = {
      models: this.presetModels,
      positionTolerance: this.positionTolerance,
      sensitivity: this.sensitivity,
      lightCompensation: this.lightCompensation,
      camera: { exposure: this.exposure, resolution: this.resolution }
    };

    try {
      await apiPost('/api/config', cfg as object);
      try {
        await apiPost('/api/ml/reload', {} as Record<string, Object>);
      } catch (e) {
      }
      AlertDialog.show({ message: '配置已保存' });
    } catch (e) {
      AlertDialog.show({ message: '保存失败' });
    }
    this.isSaving = false;
  }

  build() {
    Column() {
      // --- 1. 顶部栏 ---
      Row() {
        Button('←')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(Color.Transparent)
          .fontColor('#333333')
          .onClick(() => router.back())
        Text('系统参数配置').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 4 })
        Blank()
        if (this.isSaving) {
          LoadingProgress().width(24).height(24).color('#3B82F6')
        }
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        top: 12,
        bottom: 12
      })
      .backgroundColor('#FFFFFF')
      .border({ width: { bottom: 1 }, color: '#EEEEEE' })

      Scroll() {
        Column() {
          Column() {
            // --- 2. 预设型号列表 ---
              Column() {
                Row() {
                  Text('📋').fontSize(16)
                  Text('预设产品型号').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 8 })
                }.width('100%').margin({ bottom: 16 })

                ForEach(this.presetModels, (item: PresetModel, idx: number) => {
                  Row() {
                    Column() {
                      Text(item.name).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#333333')
                      Text(item.model).fontSize(11).fontColor('#999999').margin({ top: 2 })
                    }.layoutWeight(1).alignItems(HorizontalAlign.Start)

                    Text(item.standardLabel)
                      .fontSize(10)
                      .fontColor('#3B82F6')
                      .fontWeight(FontWeight.Bold)
                      .padding({
                        left: 8,
                        right: 8,
                        top: 4,
                        bottom: 4
                      })
                      .borderRadius(4)
                      .backgroundColor('#3B82F610')
                      .margin({ right: 12 })

                    Toggle({ type: ToggleType.Switch, isOn: item.enabled })
                      .selectedColor('#3B82F6')
                      .onChange((isOn: boolean) => {
                        this.presetModels[idx].enabled = isOn;
                      })
                  }.width('100%').padding({ top: 10, bottom: 10 })
                  .border({ width: { bottom: 1 }, color: '#F5F5F5' })
                })
              }

            // 添加新产品表单
            Column({ space: 10 }) {
              TextInput({ placeholder: '产品名称 (如: 冰箱)', text: this.newName })
                .placeholderFont({
                  size: 12
                })
                .fontSize(10).backgroundColor('#F5F5F7').height(40).onChange(v => this.newName = v)

              TextInput({ placeholder: '型号规格 (如: BCD-520W)', text: this.newModel })
                .placeholderFont({
                  size: 12
                })
                .fontSize(10).backgroundColor('#F5F5F7').height(40).onChange(v => this.newModel = v)

              Row() {
                Text('能效等级:').fontSize(12).fontColor('#666666')
                Blank()
                Select(this.labelOptions)
                  .selected(0).value(this.newLabel).font({ size: 12 })
                  .onSelect((idx, val) => {
                    this.newLabel = val;
                  })
              }
              .width('100%')
              .padding({ left: 12, right: 12 })
              .backgroundColor('#F5F5F7')
              .height(40)
              .borderRadius(12)

              Button('+ 添加新型号')
                .width('100%')
                .height(40)
                .fontSize(13)
                .fontColor('#3B82F6')
                .backgroundColor(Color.Transparent)
                .border({ width: 1, color: '#3B82F6' })
                .onClick(() => this.addModel())
            }.margin({ top: 20 })
          }
          .width('100%')
          .padding(16)
          .borderRadius(12)
          .backgroundColor('#FFFFFF')
          .margin({ bottom: 12 })
          .border({ width: 2, color: '#808080', style: BorderStyle.Dashed })

          // --- 3. 检测算法参数 ---
          Column() {
            Row() {
              Text('⚙️').fontSize(16)
              Text('智能检测参数').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 8 })
            }.width('100%').margin({ bottom: 16 })

            // --- 位置偏移容忍度 ---
            Row() {
              Text('位置偏移容忍度').fontSize(12).fontColor('#666666')
              Blank()
              // 调用子组件实现实时数字刷新
              LiveValueText({ value: this.positionTolerance + '%' })
            }.width('100%').margin({ bottom: 4 })

            Slider({
              value: this.positionTolerance,
              min: 0,
              max: 50,
              step: 1
            })
              .trackColor('#F0F0F0').selectedColor('#3B82F6').margin({ bottom: 20 })
              .onChange((value: number) => {
                this.positionTolerance = Math.round(value); // 更新状态触发子组件渲染
              })
            // 光照补偿
            Row() {
              Text('光照补偿').fontSize(12).fontColor('#666666')
              Blank()
              LiveValueText({ value: (this.lightCompensation > 0 ? '+' : '') + this.lightCompensation })
            }.width('100%').margin({ bottom: 4 })

            Slider({
              value: this.lightCompensation,
              min: -10,
              max: 10,
              step: 1
            })
              .trackColor('#F0F0F0').selectedColor('#3B82F6').margin({ bottom: 20 })
              .onChange((value: number) => {
                this.lightCompensation = Math.round(value);
              })
          }.width('100%')
          .padding(16)
          .borderRadius(12)
          .backgroundColor('#FFFFFF')
          .margin({ bottom: 12 })
          .border({ width: 2, color: '#808080', style: BorderStyle.Dashed })

          // --- 图像采集配置卡片 ---
          Column() {
            Row() {
              Text('📷').fontSize(16)
              Text('图像采集配置').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 8 })
            }.width('100%').margin({ bottom: 16 })

            // 1. 镜头曝光控制
            Row() {
              Text('镜头曝光控制').fontSize(12).fontColor('#666666')
              Blank()
              LiveValueText({ value: (this.exposure > 0 ? '+' : '') + this.exposure })
            }.width('100%').margin({ bottom: 4 })

            Slider({
              value: this.exposure,
              min: -3,
              max: 3,
              step: 1
            })
              .trackColor('#F0F0F0').selectedColor('#3B82F6').margin({ bottom: 20 })
              .onChange((v: number) => {
                this.exposure = Math.round(v);
              })
            // 2. 输出分辨率
            Text('输出分辨率').fontSize(12).fontColor('#666666').margin({ bottom: 10 })
            // 使用 Row 配合 layoutWeight 实现均匀分布
            Row({ space: 8 }) {
              ForEach(this.resolutions, (r: string) => {
                Text(r)
                  .fontSize(11)
                  .layoutWeight(1) // 关键：平分剩余空间
                  .textAlign(TextAlign.Center) // 文字居中
                  .padding({ top: 10, bottom: 10 })
                  .borderRadius(8)
                  .fontColor(this.resolution === r ? '#3B82F6' : '#999999')
                  .backgroundColor(this.resolution === r ? '#3B82F615' : '#F5F5F7')
                  .border({
                    width: 1,
                    color: this.resolution === r ? '#3B82F640' : 'transparent'
                  })
                  .onClick(() => {
                    this.resolution = r;
                  })
              })
            }.width('100%')
          }
          .width('100%')
          .padding(16)
          .borderRadius(12)
          .backgroundColor('#FFFFFF')
          .margin({ bottom: 20 })
          .border({ width: 2, color: '#808080', style: BorderStyle.Dashed })

          // --- 5. 操作按钮 ---
          Row({ space: 12 }) {
            Button('恢复默认值')
              .fontSize(14)
              .height(46)
              .layoutWeight(1)
              .backgroundColor('#ffffff')
              .fontColor('#666666')
              .borderRadius(12)
              .onClick(() => this.fetchConfig())
            Button('💾 保存并应用')
              .fontSize(14)
              .height(46)
              .layoutWeight(2)
              .backgroundColor('#3B82F6')
              .fontColor('#FFFFFF')
              .borderRadius(12)
              .enabled(!this.isSaving)
              .onClick(() => this.saveConfig())
          }.width('100%').margin({ bottom: 30 })
        }
        .width('100%')
        .padding(16)
        .layoutWeight(1)
        .backgroundColor('#F5F5F7')
      }
    }
  }
}