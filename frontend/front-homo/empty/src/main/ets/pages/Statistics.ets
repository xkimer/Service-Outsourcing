import router from '@ohos.router';
import { apiGet } from '../common/Api';

interface StatRecord {
  timestamp: string;
  status: string;
  hasDefect: boolean;
  defectType: string;
  presetModel: string;
}

interface DefectItem {
  name: string;
  count: number;
  pct: number;
}

interface ModelRate {
  model: string;
  rate: number;
}

interface ModelStat {
  total: number;
  ok: number;
}

@Entry
@Component
struct Statistics {
  @State total: number = 0;
  @State passCount: number = 0;
  @State failCount: number = 0;
  @State passRate: number = 0;
  @State defectDist: DefectItem[] = [];
  @State modelRates: ModelRate[] = [];
  @State isLoading: boolean = false;

  aboutToAppear() {
    this.fetchStats();
  }

  async fetchStats() {
    this.isLoading = true;
    try {
      let data = await apiGet('/api/statistic') as StatRecord[];
      let arr = data || [];
      this.total = arr.length;
      this.passCount = arr.filter((d: StatRecord) => d.status === 'OK').length;
      this.failCount = this.total - this.passCount;
      this.passRate = this.total > 0 ? Math.round(this.passCount / this.total * 100) : 0;

      // 缺陷分布
      let dc: Record<string, number> = {};
      arr.forEach((item: StatRecord) => {
        let defect = item.defectType;
        if (!defect || defect === '无' || defect === 'none') return;
        defect.split(',').forEach((t: string) => {
          let n = t.trim();
          if (n && n !== '无') dc[n] = (dc[n] || 0) + 1;
        });
      });
      let maxCount = Math.max(...Object.values(dc), 1);
      this.defectDist = Object.keys(dc).map((name: string): DefectItem => ({
        name: name,
        count: dc[name],
        pct: Math.round(dc[name] / maxCount * 100)
      } as DefectItem)).sort((a: DefectItem, b: DefectItem) => b.count - a.count);

      // 型号合格率
      let ms: Record<string, ModelStat> = {};
      arr.forEach((item: StatRecord) => {
        let m = item.presetModel || '未知';
        if (!ms[m]) ms[m] = { total: 0, ok: 0 };
        ms[m].total++;
        if (item.status === 'OK') ms[m].ok++;
      });
      this.modelRates = Object.keys(ms).map((model: string): ModelRate => ({
        model: model,
        rate: ms[model].total > 0 ? Math.round(ms[model].ok / ms[model].total * 100) : 0
      } as ModelRate));
    } catch (e) {}
    this.isLoading = false;
  }

  build() {
    Column() {
      // --- 1. 顶部栏 ---
      Row() {
        Button('←').fontSize(18).fontWeight(FontWeight.Bold).backgroundColor(Color.Transparent).fontColor('#333333')
          .onClick(() => router.back())
        Text('数据分析统计').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 4 })
        Blank()
        if (this.isLoading) {
          LoadingProgress().width(24).height(24).color('#3B82F6')
        }
      }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#FFFFFF').border({ width: { bottom: 1 }, color: '#EEEEEE' })

      Scroll() {
        Column() {
          // --- 2. 核心指标卡片 (Grid布局感) ---
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
            this.StatCard('总检测', this.total.toString(), '#333333')
            this.StatCard('合格数', this.passCount.toString(), '#10B981')
            this.StatCard('异常数', this.failCount.toString(), '#EF4444')
            this.StatCard('合格率', this.passRate + '%', '#3B82F6')
          }.width('100%').margin({ bottom: 12 })

          // --- 3. 缺陷分布分析 ---
          Column() {
            Row() {
              Text('🍕').fontSize(16)
              Text('缺陷类型频率分布').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 8 })
            }.width('100%').margin({ bottom: 16 })

            if (this.defectDist.length > 0) {
              ForEach(this.defectDist, (item: DefectItem) => {
                Column() {
                  Row() {
                    Text(item.name).fontSize(12).fontColor('#666666')
                    Blank()
                    Text(item.count + ' 例').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#333333')
                  }.width('100%').margin({ bottom: 6 })

                  // 自定义进度条
                  Stack({ alignContent: Alignment.Start }) {
                    Rect().width('100%').height(8).radius(4).fill('#F0F0F0')
                    Rect().width(item.pct + '%').height(8).radius(4).fill('#6366F1')
                  }.width('100%').margin({ bottom: 12 })
                }
              })
            } else {
              this.EmptyView()
            }
          }.width('100%').padding(16).borderRadius(12).backgroundColor('#FFFFFF')
          .margin({ bottom: 12 }).border({ width: 2, color: '#808080', style: BorderStyle.Dashed })

          // --- 4. 型号质量对比 ---
          Column() {
            Row() {
              Text('📊').fontSize(16)
              Text('各型号合格率分析').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 8 })
            }.width('100%').margin({ bottom: 16 })

            if (this.modelRates.length > 0) {
              ForEach(this.modelRates, (item: ModelRate) => {
                Row() {
                  Text(item.model).fontSize(12).fontColor('#333333').width(80).maxLines(1)

                  Stack({ alignContent: Alignment.Start }) {
                    Rect().width('100%').height(10).radius(5).fill('#F0F0F0')
                    Rect().width(item.rate + '%').height(10).radius(5)
                      .fill(item.rate >= 90 ? '#10B981' : (item.rate >= 75 ? '#3B82F6' : '#EF4444'))
                  }.layoutWeight(1).margin({ left: 10, right: 10 })

                  Text(item.rate + '%').fontSize(12).fontWeight(FontWeight.Bold)
                    .fontColor(item.rate >= 90 ? '#10B981' : (item.rate >= 75 ? '#3B82F6' : '#EF4444'))
                    .width(40).textAlign(TextAlign.End)
                }.width('100%').margin({ bottom: 14 })
              })
            } else {
              this.EmptyView()
            }
          }.width('100%').padding(16).borderRadius(12).backgroundColor('#FFFFFF')
          .border({ width: 2, color: '#808080', style: BorderStyle.Dashed })

        }.width('100%').padding({ left: 16, right: 16, bottom: 20 })
      }.layoutWeight(1)
    }.width('100%').height('100%').backgroundColor('#F5F5F7')
  }

  // 自定义小卡片组件
  @Builder StatCard(title: string, value: string, color: string) {
    Column() {
      Text(title).fontSize(11).fontColor('#999999').margin({ bottom: 4 })
      Text(value).fontSize(22).fontWeight(FontWeight.Bold).fontColor(color)
    }
    .width('48%') // 每行两个
    .margin({ bottom: 10 })
    .padding(14)
    .borderRadius(10)
    .backgroundColor('#FFFFFF')
    .border({ width: 2, color: '#808080', style: BorderStyle.Dashed })
  }

  // 空数据展示
  @Builder EmptyView() {
    Column() {
      Text('🧊').fontSize(30).opacity(0.3)
      Text('暂无统计数据').fontSize(12).fontColor('#CCCCCC').margin({ top: 8 })
    }.width('100%').padding(20).alignItems(HorizontalAlign.Center)
  }
}