import webSocket from '@ohos.net.webSocket';
import { BASE_URL } from './Api';
import { BusinessError } from '@ohos.base'; // 导入标准错误类型

export class WebSocketClient {
  private ws: webSocket.WebSocket | null = null;
  private wsUrl: string = '';
  private onMessage: ((data: object) => void) | null = null;
  private onStatusChange: ((connected: boolean) => void) | null = null;
  private heartbeatTimer: number = -1;
  private reconnectTimer: number = -1;
  private isConnected: boolean = false;
  private shouldReconnect: boolean = true;
  private reconnectDelay: number = 3000;

  constructor() {
    let base = BASE_URL.replace('http://', 'ws://').replace('https://', 'wss://');
    this.wsUrl = base + '/ws/detection';
  }

  setOnMessage(callback: (data: object) => void) {
    this.onMessage = callback;
  }

  setOnStatusChange(callback: (connected: boolean) => void) {
    this.onStatusChange = callback;
  }

  connect() {
    this.shouldReconnect = true;
    this.doConnect();
  }

  private doConnect() {
    try {
      this.ws = webSocket.createWebSocket();

      this.ws.on('open', () => {
        this.isConnected = true;
        if (this.onStatusChange) this.onStatusChange(true);
        this.startHeartbeat();
      });

      this.ws.on('message', (err: BusinessError, data: string | ArrayBuffer) => {
        if (err) return;

        let msgStr: string = '';
        if (typeof data === 'string') {
          msgStr = data;
        } else {
          msgStr = this.utf8ArrayBufferToString(data);
        }

        if (msgStr === 'pong') return;
        try {
          const parsed = JSON.parse(msgStr) as object;
          if (this.onMessage) this.onMessage(parsed);
        } catch (e) {
          // 忽略非JSON
        }
      });

      this.ws.on('close', () => {
        this.handleDisconnect();
      });

      this.ws.on('error', () => {
        this.handleDisconnect();
      });

      // 关键修改：增加异常捕获
      this.ws.connect(this.wsUrl, (err: BusinessError) => {
        if (err) {
          this.handleDisconnect();
        }
      });
    } catch (e) {
      this.handleDisconnect();
    }
  }

  private handleDisconnect() {
    this.isConnected = false;
    if (this.onStatusChange) this.onStatusChange(false);
    this.stopHeartbeat();
    if (this.shouldReconnect) {
      this.scheduleReconnect();
    }
  }

  private startHeartbeat() {
    this.stopHeartbeat();
    // 修正：去掉 as unknown as number
    this.heartbeatTimer = setInterval(() => {
      if (this.ws && this.isConnected) {
        try {
          this.ws.send('ping', (err: BusinessError) => {
            if (err) { /* 发送失败处理 */ }
          });
        } catch (e) { /* ignore */ }
      }
    }, 30000);
  }

  private stopHeartbeat() {
    if (this.heartbeatTimer !== -1) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = -1;
    }
  }

  private scheduleReconnect() {
    if (this.reconnectTimer !== -1) return;
    // 修正：去掉 as unknown as number
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = -1;
      this.doConnect();
    }, this.reconnectDelay);
  }

  disconnect() {
    this.shouldReconnect = false;
    this.stopHeartbeat();
    if (this.reconnectTimer !== -1) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = -1;
    }
    if (this.ws) {
      try { this.ws.close(); } catch (e) { /* ignore */ }
      this.ws = null;
    }
    this.isConnected = false;
  }

  getConnected(): boolean {
    return this.isConnected;
  }

  private utf8ArrayBufferToString(ab: ArrayBuffer): string {
    const bytes = new Uint8Array(ab);
    let out = '';
    let i = 0;
    while (i < bytes.length) {
      const byte1 = bytes[i++];
      if (byte1 < 0x80) {
        out += String.fromCharCode(byte1);
      } else if (byte1 >= 0xc0 && byte1 < 0xe0) {
        const byte2 = bytes[i++] || 0;
        const codePoint = ((byte1 & 0x1f) << 6) | (byte2 & 0x3f);
        out += String.fromCharCode(codePoint);
      } else if (byte1 >= 0xe0 && byte1 < 0xf0) {
        const byte2 = bytes[i++] || 0;
        const byte3 = bytes[i++] || 0;
        const codePoint = ((byte1 & 0x0f) << 12) | ((byte2 & 0x3f) << 6) | (byte3 & 0x3f);
        out += String.fromCharCode(codePoint);
      } else if (byte1 >= 0xf0 && byte1 < 0xf8) {
        const byte2 = bytes[i++] || 0;
        const byte3 = bytes[i++] || 0;
        const byte4 = bytes[i++] || 0;
        let codePoint = ((byte1 & 0x07) << 18) | ((byte2 & 0x3f) << 12) | ((byte3 & 0x3f) << 6) | (byte4 & 0x3f);
        codePoint -= 0x10000;
        const highSurrogate = 0xD800 + ((codePoint >> 10) & 0x3FF);
        const lowSurrogate = 0xDC00 + (codePoint & 0x3FF);
        out += String.fromCharCode(highSurrogate, lowSurrogate);
      }
    }
    return out;
  }
}