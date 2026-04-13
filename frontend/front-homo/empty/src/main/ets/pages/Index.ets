import router from '@ohos.router';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import http from '@ohos.net.http';
import util from '@ohos.util';
import { apiGet, BASE_URL } from '../common/Api';
import { WebSocketClient } from '../common/WebSocketClient';

interface DetectionResult {
  status: string;
  ocrText: string;
  presetModel: string;
  isMatch: boolean;
  defectType: string;
  positionStatus: string;
  positionX: number;
  positionY: number;
  timestamp: string;
  imageUrl: string;
  confidence: number;
}

interface RecentRecord {
  timestamp: string;
  presetModel: string;
  status: string;
  defectType: string;
  positionStatus: string;
}

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State currentResult: DetectionResult = {
    status: '', ocrText: '', presetModel: '', isMatch: false,
    defectType: '无', positionStatus: '正常', positionX: 50, positionY: 50,
    timestamp: '', imageUrl: '', confidence: 0
  };
  @State recentList: RecentRecord[] = [];
  @State mlAvailable: boolean = false;
  @State isLoading: boolean = false;
  @State wsConnected: boolean = false;
  @State previewUri: string = '';
  @State detecting: boolean = false;

  private wsClient: WebSocketClient = new WebSocketClient();
  private tabs: string[] = ['监控', '历史', '统计', '设置'];
  private tabIcons: string[] = ['📡', '📋', '📊', '⚙️'];
  private defectNames: string[] = ['破损', '污渍', '褶皱', '划痕', '偏移'];
  private defectIcons: string[] = ['💔', '💧', '📄', '🔪', '↔️'];

  aboutToAppear() {
    this.loadData();
    // WebSocket 实时推送
    this.wsClient.setOnMessage((data: object) => {
      let d = data as Record<string, string | number | boolean>;
      if (d['type'] === 'detection_result') {
        // 收到新检测结果，刷新数据
        this.loadData();
      }
    });
    this.wsClient.setOnStatusChange((connected: boolean) => {
      this.wsConnected = connected;
    });
    this.wsClient.connect();
  }

  aboutToDisappear() {
    this.wsClient.disconnect();
  }

  async loadData() {
    this.isLoading = true;
    try {
      let status = await apiGet('/api/ml/status') as Record<string, boolean>;
      this.mlAvailable = status.available === true;
    } catch (e) {}
    try {
      let result = await apiGet('/api/current') as DetectionResult;
      if (result.status) {
        this.currentResult = {
          status: result.status || '',
          ocrText: result.ocrText || '',
          presetModel: result.presetModel || '',
          isMatch: result.isMatch || false,
          defectType: result.defectType || '无',
          positionStatus: result.positionStatus || '正常',
          positionX: result.positionX || 50,
          positionY: result.positionY || 50,
          timestamp: result.timestamp || '',
          imageUrl: result.imageUrl || '',
          confidence: result.confidence || 0
        };
      }
    } catch (e) {}
    try {
      let records = await apiGet('/api/recent?limit=10') as RecentRecord[];
      this.recentList = records.map((item: RecentRecord): RecentRecord => ({
        timestamp: item.timestamp || '',
        presetModel: item.presetModel || '',
        status: item.status || '',
        defectType: item.defectType || '无',
        positionStatus: item.positionStatus || '正常'
      } as RecentRecord));
    } catch (e) {}
    this.isLoading = false;
  }

  async pickImage() {
    try {
      let photoPicker = new picker.PhotoViewPicker();
      let options: picker.PhotoSelectOptions = {
        MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      };
      let result = await photoPicker.select({ MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE, maxSelectNumber: 1 });
      if (result.photoUris && result.photoUris.length > 0) {
        this.previewUri = result.photoUris[0];
      }
    } catch (e) { /* user cancelled */ }
  }

  encodeUtf8(text: string): Uint8Array {
    const encoder = new util.TextEncoder();
    return encoder.encodeInto(text);
  }

  mergeBytes(parts: Uint8Array[]): ArrayBuffer {
    let total = 0;
    for (let i = 0; i < parts.length; i++) {
      total += parts[i].length;
    }

    const merged = new Uint8Array(total);
    let offset = 0;

    for (let i = 0; i < parts.length; i++) {
      merged.set(parts[i], offset);
      offset += parts[i].length;
    }

    return merged.buffer as ArrayBuffer;
  }

  async doDetect() {
    if (this.previewUri === '' || this.detecting) {
      return;
    }

    this.detecting = true;

    let tmpPath: string = '';
    let req: http.HttpRequest | null = null;

    try {
      const context = getContext(this);

      // 1. 先把选择的图片复制到应用 cache 目录
      const srcFile = await fs.open(this.previewUri, fs.OpenMode.READ_ONLY);

      const fileName: string = 'upload_' + Date.now() + '.jpg';
      tmpPath = context.cacheDir + '/' + fileName;

      const dstFile = await fs.open(tmpPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);

      const copyBuf = new ArrayBuffer(4 * 1024 * 1024);
      const copyLen = await fs.read(srcFile.fd, copyBuf);
      await fs.write(dstFile.fd, copyBuf, { length: copyLen });

      await fs.close(srcFile);
      await fs.close(dstFile);

      // 2. 再把 cache 里的 jpg 按“二进制”读出来
      const uploadFile = await fs.open(tmpPath, fs.OpenMode.READ_ONLY);
      const fileBuf = new ArrayBuffer(4 * 1024 * 1024);
      const fileLen = await fs.read(uploadFile.fd, fileBuf);
      await fs.close(uploadFile);

      const fileBytes = new Uint8Array(fileBuf.slice(0, fileLen));

      // 3. 手动拼 multipart/form-data body
      const boundary: string = '----HarmonyBoundary' + Date.now();
      const crlf: string = '\r\n';

      const partHeader: string =
        '--' + boundary + crlf +
          'Content-Disposition: form-data; name="file"; filename="detect.jpg"' + crlf +
          'Content-Type: image/jpeg' + crlf + crlf;

      const partFooter: string =
        crlf + '--' + boundary + '--' + crlf;

      const headerBytes = this.encodeUtf8(partHeader);
      const footerBytes = this.encodeUtf8(partFooter);

      const requestBody: ArrayBuffer = this.mergeBytes([
        headerBytes,
        fileBytes,
        footerBytes
      ]);

      // 4. 发 HTTP 请求
      req = http.createHttp();

      const respText: string = await new Promise<string>((resolve, reject) => {
        if (req === null) {
          reject(new Error('HTTP request not created'));
          return;
        }

        req.request(
          BASE_URL + '/api/ml/detect',
          {
            method: http.RequestMethod.POST,
            header: {
              'Content-Type': 'multipart/form-data; boundary=' + boundary,
              'Accept': 'application/json'
            },
            extraData: requestBody,
            connectTimeout: 60000,
            readTimeout: 60000
          },
          (err, data) => {
            try {
              if (err) {
                reject(new Error(JSON.stringify(err)));
                return;
              }

              if (!data || data.responseCode !== 200) {
                reject(new Error('HTTP ' + (data ? data.responseCode : 'unknown')));
                return;
              }

              if (typeof data.result === 'string') {
                resolve(data.result as string);
              } else {
                resolve(JSON.stringify(data.result));
              }
            } catch (e) {
              reject(e);
            }
          }
        );
      });

      req.destroy();
      req = null;

      // 5. 解析后端返回
      const d = JSON.parse(respText) as Record<string, string | number | boolean>;

      this.currentResult = {
        status: (d['status'] as string) || ((d['is_qualified'] as boolean) ? 'OK' : 'NG'),
        ocrText: (d['ocr_text'] as string) || '',
        presetModel: (d['preset_model'] as string) || '',
        isMatch: (d['is_qualified'] as boolean) || false,
        defectType: (d['defect_type'] as string) || '无',
        positionStatus: (d['position_status'] as string) || '正常',
        positionX: d['position_x'] ? Math.round((d['position_x'] as number) * 100) : 50,
        positionY: d['position_y'] ? Math.round((d['position_y'] as number) * 100) : 50,
        timestamp: (d['timestamp'] as string) || new Date().toLocaleTimeString(),
        imageUrl: (d['image_url'] as string) || '',
        confidence: (d['confidence'] as number) || 0
      };

      await this.loadData();

      AlertDialog.show({
        message: (d['is_qualified'] as boolean) ? '检测合格 ✓' : '检测不合格 ✗'
      });
    } catch (e) {
      let errMsg: string = '未知错误';

      if (e instanceof Error) {
        errMsg = e.message;
      } else {
        errMsg = JSON.stringify(e);
      }

      AlertDialog.show({
        message: '检测失败: ' + errMsg
      });
    } finally {
      if (req !== null) {
        try {
          req.destroy();
        } catch (e) {}
      }

      if (tmpPath !== '') {
        try {
          await fs.unlink(tmpPath);
        } catch (e) {}
      }

      this.detecting = false;
    }
  }

  onTabChange(idx: number) {
    if (idx === 0) {
      this.loadData();
      return;
    }
    let pages: string[] = ['', 'pages/History', 'pages/Statistics', 'pages/Settings'];
    if (pages[idx]) {
      router.pushUrl({ url: pages[idx] });
    }
  }

  build() {
    Column() {
      // --- 1. 顶部栏 (白色背景 + 细分割线) ---
      Row() {
        Column() {
          Text('实时监控').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333333')
          Text('上传图片检测能效标签').fontSize(12).fontColor('#999999').margin({ top: 4 })
        }.alignItems(HorizontalAlign.Start)

        Blank()

        Row() {
          Circle({ width: 8, height: 8 }).fill(this.mlAvailable ? '#10B981' : '#EF4444')
          Text(this.mlAvailable ? 'ML就绪' : 'ML离线')
            .fontSize(11).fontColor(this.mlAvailable ? '#10B981' : '#EF4444').margin({ left: 6 })
        }.padding({ left: 10, right: 10, top: 4, bottom: 4 }).borderRadius(16)
        .backgroundColor(this.mlAvailable ? '#10B98115' : '#EF444415')
        // WS 状态
        Row() {
          Circle({ width: 6, height: 6 }).fill(this.wsConnected ? '#06B6D4' : '#666666')
          Text('WS').fontSize(9).fontColor(this.wsConnected ? '#06B6D4' : '#666666').margin({ left: 4 })
        }.padding({ left: 6, right: 6, top: 2, bottom: 2 }).borderRadius(10).backgroundColor('#FFFFFF08').margin({ left: 6 })

        Button('刷新').fontSize(11).height(28).margin({ left: 8 })
          .backgroundColor('#F0F0F0').fontColor('#666666')
          .onClick(() => this.loadData())
      }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#FFFFFF').border({ width: { bottom: 1 }, color: '#EEEEEE' })

      // --- 2. 图片上传区域 (卡片化 + 虚线边框) ---
      Column() {
        Text('📤 图片检测').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ bottom: 12 })

        if (this.detecting) {
          // 检测中的 Loading 状态
          Column() {
            LoadingProgress().width(40).height(40).color('#3B82F6')
            Text('正在分析标签内容...').fontSize(13).fontColor('#3B82F6').margin({ top: 8 })
          }.width('100%').height(120).justifyContent(FlexAlign.Center)
          .border({ width: 1.5, color: '#3B82F640', style: BorderStyle.Dashed }).borderRadius(10)
        } else if (this.previewUri !== '') {
          // 已选择图片预览
          Image(this.previewUri).width('100%').height(180).objectFit(ImageFit.Contain).borderRadius(8)
        } else {
          // 未选择图片的占位框
          Row() {
            Column() {
              Text('📷').fontSize(30).fontColor('#CCCCCC')
              Text('点击此处上传标签图片').fontSize(12).fontColor('#999999').margin({ top: 8 })
            }.alignItems(HorizontalAlign.Center)
          }.width('100%').height(120).justifyContent(FlexAlign.Center).borderRadius(10)
          .border({ width: 1.5, color: '#CCCCCC', style: BorderStyle.Dashed }).backgroundColor('#FAFAFA')
          .onClick(() => this.pickImage())
        }

        Row() {
          Button('📁 选择图片').fontSize(12).height(36).layoutWeight(1.5).backgroundColor('#F5F5F5').fontColor('#666666')
            .borderRadius(8).onClick(() => this.pickImage())

          Button('🔍 开始检测').fontSize(12).height(36).layoutWeight(1.5).backgroundColor('#3B82F6').fontColor('#FFFFFF')
            .borderRadius(8).margin({ left: 8 }).enabled(this.previewUri !== '' && !this.detecting)
            .opacity(this.previewUri !== '' && !this.detecting ? 1.0 : 0.5)
            .onClick(() => this.doDetect())

          Button('清除').fontSize(12).height(36).layoutWeight(1).backgroundColor('#F5F5F5').fontColor('#666666')
            .borderRadius(8).margin({ left: 8 }).onClick(() => { this.previewUri = ''; })
        }.width('100%').margin({ top: 12 })
      }.width('92%').padding(16).borderRadius(12).backgroundColor('#FFFFFF')
      .margin({ top: 12, bottom: 8 })
      .border({ width: 2, color: '#808080', style: BorderStyle.Dashed })

      // --- 3. 滚动内容区 ---
      Scroll() {
        Column() {
          if (this.currentResult.status !== '') {
            // 结果状态显示 (使用 Stack 替代 overlay 避错)
            Row() {
              Stack() {
                Circle({ width: 44, height: 44 }).fill(this.currentResult.status === 'OK' ? '#10B98115' : '#EF444415')
                Text(this.currentResult.status === 'OK' ? '✓' : '✗')
                  .fontSize(22).fontWeight(FontWeight.Bold)
                  .fontColor(this.currentResult.status === 'OK' ? '#10B981' : '#EF4444')
              }

              Column() {
                Text(this.currentResult.status === 'OK' ? '检测结果：合格' : '检测结果：不合格')
                  .fontSize(17).fontWeight(FontWeight.Bold).fontColor('#333333')
                Text('时间: ' + this.currentResult.timestamp).fontSize(11).fontColor('#999999').margin({ top: 4 })
              }.margin({ left: 12 }).alignItems(HorizontalAlign.Start)
            }.width('100%').padding(16).borderRadius(12).backgroundColor('#FFFFFF').margin({ bottom: 12 })
            .border({ width: 2, color: '#808080', style: BorderStyle.Dashed })

            // 详细参数列表
            Column() {
              Text('📋 识别详情').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ bottom: 12 })

              this.infoRow('识别内容', this.currentResult.ocrText || '--', '#3B82F6')
              this.infoRow('预设型号', this.currentResult.presetModel || '--', '#666666')
              this.infoRow('置信度', this.currentResult.confidence > 0 ? (this.currentResult.confidence * 100).toFixed(1) + '%' : '--', '#666666')
              this.infoRow('比对验证', this.currentResult.isMatch ? '验证通过' : '匹配失败', this.currentResult.isMatch ? '#10B981' : '#EF4444')
            }.width('100%').padding(16).borderRadius(12).backgroundColor('#FFFFFF').margin({ bottom: 12 })
            .border({ width: 2, color: '#808080', style: BorderStyle.Dashed })

            // 粘贴位置与缺陷
            Row({ space: 12 }) {
              Column() {
                Text('📍 粘贴位置').fontSize(13).fontColor('#999999').margin({ bottom: 4 })
                Text(this.currentResult.positionStatus).fontSize(15).fontWeight(FontWeight.Bold)
                  .fontColor(this.currentResult.positionStatus === '正常' ? '#10B981' : '#EF4444')
              }.layoutWeight(1).padding(12).backgroundColor('#FFFFFF').borderRadius(12).border({ width: 1, color: '#E0E0E0', style: BorderStyle.Dashed })

              Column() {
                Text('⚠️ 缺陷类型').fontSize(13).fontColor('#999999').margin({ bottom: 4 })
                Text(this.currentResult.defectType || '无').fontSize(15).fontWeight(FontWeight.Bold)
                  .fontColor(this.currentResult.defectType === '无' ? '#10B981' : '#EF4444')
              }.layoutWeight(1).padding(12).backgroundColor('#FFFFFF').borderRadius(12).border({ width: 1, color: '#E0E0E0', style: BorderStyle.Dashed })
            }.width('100%').margin({ bottom: 12 })

          } else {
            // 空状态显示
            Column() {
              Text('🔍').fontSize(50).opacity(0.2)
              Text('暂无检测数据，请点击上方上传图片').fontSize(13).fontColor('#CCCCCC').margin({ top: 12 })
            }.width('100%').padding(40)
          }

          // 底部历史记录列表
          Column() {
            Text('📝 最近检测历史').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#333333').margin({ bottom: 12 })

            // 表头
            Row() {
              Text('时间').fontSize(10).fontColor('#999999').width('25%').textAlign(TextAlign.Center)
              Text('型号').fontSize(10).fontColor('#999999').width('20%').textAlign(TextAlign.Center)
              Text('结果').fontSize(10).fontColor('#999999').width('10%').textAlign(TextAlign.Center)
              Text('缺陷类型').fontSize(10).fontColor('#999999').width('22.5%').textAlign(TextAlign.Center)
              Text('位置情况').fontSize(10).fontColor('#999999').width('22.5%').textAlign(TextAlign.Center)
            }.width('100%').padding({ bottom: 8 }).border({ width: { bottom: 1 }, color: '#F0F0F0' })

            if (this.recentList.length > 0) {
              ForEach(this.recentList, (item: RecentRecord) => {
                Row() {
                  Text(item.timestamp.slice(-8)).fontSize(11).fontColor('#666666').width('25%').textAlign(TextAlign.Center)
                  Text(item.presetModel).fontSize(11).fontColor('#333333').width('20%').maxLines(1).textAlign(TextAlign.Center)
                  Text(item.status).fontSize(11).fontWeight(FontWeight.Bold)
                    .fontColor(item.status === 'OK' ? '#10B981' : '#EF4444').width('10%').textAlign(TextAlign.Center)
                  Text(item.defectType).fontSize(11).fontColor('#999999').width('22.5%').textAlign(TextAlign.Center)
                  Text(item.positionStatus).fontSize(11).fontColor('#999999').width('22.5%').textAlign(TextAlign.Center)
                }.width('100%').padding({ top: 12, bottom: 12 }).border({ width: { bottom: 1 }, color: '#F9F9F9' })
              })
            }
          }.width('100%').padding(16).borderRadius(12).backgroundColor('#FFFFFF')
          .border({ width: 2, color: '#808080', style: BorderStyle.Dashed })

        }.width('100%').padding({ left: 16, right: 16, bottom: 30 })
      }.layoutWeight(1)

      // --- 4. 底部导航栏 ---
      Row() {
        ForEach(this.tabs, (tab: string, idx: number) => {
          Column() {
            Text(this.tabIcons[idx]).fontSize(22).opacity(this.currentTab === idx ? 1.0 : 0.4)
            Text(tab).fontSize(10).fontColor(this.currentTab === idx ? '#3B82F6' : '#999999').margin({ top: 4 })
          }.layoutWeight(1).onClick(() => { this.currentTab = idx; this.onTabChange(idx); })
        })
      }.width('100%').height(65).backgroundColor('#FFFFFF').border({ width: { top: 1 }, color: '#EEEEEE' })

    }.width('100%').height('100%').backgroundColor('#F5F5F7')
  }

  // 辅助函数：渲染详情行
  @Builder infoRow(label: string, value: string, vColor: string) {
    Row() {
      Text(label).fontSize(12).fontColor('#999999')
      Blank()
      Text(value).fontSize(13).fontWeight(FontWeight.Medium).fontColor(vColor)
    }.width('100%').margin({ bottom: 8 })
  }
}