import router from '@ohos.router';

import { apiGet } from '../common/Api';

interface HistoryRecord {
  timestamp: string;
  presetModel: string;
  ocrText: string;
  status: string;
  defectType: string;
  positionStatus: string;
  imageUrl: string;
}

interface HistoryResponse {
  total: number;
  records: HistoryRecord[];
}

@Entry
@Component
struct History {
  @State records: HistoryRecord[] = [];
  @State total: number = 0;
  @State page: number = 1;
  @State isLoading: boolean = false;
  @State statusFilter: string = 'ALL';

  private pageSize: number = 20;
  private statusOptions: string[] = ['ALL', 'OK', 'NG'];
  private statusLabels: string[] = ['全部', '合格', '不合格'];
  @State statusIdx: number = 0;
  @State selectedDate: string = '全部日期'; // 当前选中的日期显示
  private dateOptions: string[] = ['全部日期']; // 存储近30天的日期字符串列表

  aboutToAppear() {
    this.generateDateOptions();
    this.fetchHistory();
  }

  // 生成近30天的日期列表 [全部日期, 2024-05-20, ...]
  generateDateOptions() {
    const dates = ['全部日期'];
    for (let i = 0; i < 30; i++) {
      let d = new Date();
      d.setDate(d.getDate() - i);
      // 格式化为 YYYY-MM-DD
      let dateStr = `${d.getFullYear()}-${(d.getMonth() + 1).toString().padStart(2, '0')}-${d.getDate().toString().padStart(2, '0')}`;
      dates.push(dateStr);
    }
    this.dateOptions = dates;
  }

  async fetchHistory() {
    if (this.isLoading) return;
    this.isLoading = true;
    try {
      let resp = await apiGet(`/api/history?page=${this.page}&pageSize=${this.pageSize}&statusFilter=${this.statusFilter}`) as HistoryResponse;
      this.total = resp.total;
      if (this.page === 1) {
        this.records = resp.records || [];
      } else {
        this.records = this.records.concat(resp.records || []);
      }
    } catch (e) {}
    this.isLoading = false;
  }

  build() {
    Column() {
      // --- 1. 顶部导航栏 (纯白 + 分割线) ---
      Row() {
        Button('←').fontSize(18).fontWeight(FontWeight.Bold).backgroundColor(Color.Transparent).fontColor('#333333')
          .onClick(() => router.back())
        Text('历史记录').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ left: 4 })
        Blank()
        Text(`共 ${this.total} 条`).fontSize(12).fontColor('#999999')
      }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#FFFFFF').border({ width: { bottom: 1 }, color: '#EEEEEE' })

      // --- 2. 筛选栏 (浅色胶囊样式) ---
      Row() {
        // 原有的 合格/不合格 筛选
        Row({ space: 8 }) {
          ForEach(this.statusLabels, (label: string, idx: number) => {
            Text(label).fontSize(12).fontColor(this.statusIdx === idx ? '#3B82F6' : '#666666')
              .padding({ left: 14, right: 14, top: 6, bottom: 6 }).borderRadius(16)
              .backgroundColor(this.statusIdx === idx ? '#3B82F615' : '#FFFFFF')
              .border({ width: 1, color: this.statusIdx === idx ? '#3B82F640' : '#E0E0E0' })
              .onClick(() => {
                this.statusIdx = idx;
                this.statusFilter = this.statusOptions[idx];
                this.page = 1;
                this.records = [];
                this.fetchHistory();
              })
          })
        }.layoutWeight(1)

        // 新增的日期筛选按钮
        Row() {
          Text(this.selectedDate === '全部日期' ? '📅 选日期' : this.selectedDate)
            .fontSize(12).fontColor('#333333')
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor('#FFFFFF').borderRadius(16).border({ width: 1, color: '#E0E0E0' })
        // --- 找到代码中的这一块进行修改 ---
        .onClick(() => {
          TextPickerDialog.show({
            range: this.dateOptions,
            selected: this.dateOptions.indexOf(this.selectedDate),
            onAccept: (value: TextPickerResult) => {
              // 这里的关键：显式转为 string，消除 image_118ac8.png 里的红线
              let resultValue = value.value as string;

              this.selectedDate = resultValue;
              this.page = 1;
              this.records = [];

              // 执行数据刷新
              this.fetchHistory();
            }
          })
        })
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })

      // --- 3. 记录列表 (滚动区) ---
      Scroll() {
        Column() {
          if (this.records.length > 0) {
            ForEach(this.records, (item: HistoryRecord) => {
              // 每一条记录卡片
              Column() {
                Row() {
                  // 时间戳使用小字号中灰色
                  Text('🕒 ' + item.timestamp).fontSize(11).fontColor('#999999')
                  Blank()
                  // 状态标签
                  Text(item.status === 'OK' ? '合格 ✓' : '不合格 ✗')
                    .fontSize(11).fontWeight(FontWeight.Bold)
                    .fontColor(item.status === 'OK' ? '#10B981' : '#EF4444')
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 }).borderRadius(6)
                    .backgroundColor(item.status === 'OK' ? '#10B98110' : '#EF444410')
                }.width('100%').margin({ bottom: 12 })

                // 数据内容区
                Column({ space: 8 }) {
                  this.HistoryItemRow('预设型号', item.presetModel || '--')
                  this.HistoryItemRow('标签识别', item.ocrText || '--')
                  this.HistoryItemRow('缺陷类型', item.defectType || '无')

                  Row() {
                    Text('粘贴位置').fontSize(12).fontColor('#999999')
                    Blank()
                    Text(item.positionStatus)
                      .fontSize(12).fontWeight(FontWeight.Medium)
                      .fontColor(item.positionStatus === '正常' ? '#10B981' : '#EF4444')
                  }.width('100%')
                }
              }
              .width('100%').padding(16).borderRadius(12).backgroundColor('#FFFFFF')
              .margin({ bottom: 12 })
              .border({ width: 2, color: '#808080', style: BorderStyle.Dashed }) // 统一虚线风格
            })

            // 加载更多按钮
            if (this.records.length < this.total) {
              Button('加载更多记录').fontSize(13).height(40).width('100%')
                .backgroundColor('#FFFFFF').fontColor('#3B82F6')
                .border({ width: 1, color: '#3B82F6', style: BorderStyle.Dashed })
                .margin({ top: 8, bottom: 20 })
                .onClick(() => { this.page++; this.fetchHistory(); })
            } else {
              Text('— 已显示全部记录 —').fontSize(11).fontColor('#CCCCCC')
                .width('100%').textAlign(TextAlign.Center).padding(20)
            }
          } else if (!this.isLoading) {
            // 空状态
            Column() {
              Text('📒').fontSize(50).opacity(0.2)
              Text('暂无相关历史记录').fontSize(14).fontColor('#CCCCCC').margin({ top: 12 })
            }.width('100%').padding(80).alignItems(HorizontalAlign.Center)
          }

          if (this.isLoading) {
            Row() {
              LoadingProgress().width(24).height(24).color('#3B82F6')
              Text(' 正在加载...').fontSize(12).fontColor('#999999')
            }.width('100%').justifyContent(FlexAlign.Center).padding(20)
          }
        }.width('100%').padding({ left: 16, right: 16 })
      }.width('100%').layoutWeight(1)
    }.width('100%').height('100%').backgroundColor('#F5F5F7') // 全局浅灰背景
  }

  // 辅助函数：历史项属性行
  @Builder HistoryItemRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor('#999999')
      Blank()
      Text(value).fontSize(12).fontColor('#333333').fontWeight(FontWeight.Medium)
    }.width('100%')
  }
}