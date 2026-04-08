import http from '@ohos.net.http';

// 后端地址 — 部署时修改为实际 IP
const BASE_URL: string = 'http://192.168.1.100:8000';

// 通用 GET 请求
export function apiGet(path: string): Promise<object> {
  return new Promise((resolve, reject) => {
    let req = http.createHttp();
    req.request(BASE_URL + path, { method: http.RequestMethod.GET }, (err, data) => {
      if (!err && data.responseCode === 200) {
        try {
          resolve(JSON.parse(data.result as string));
        } catch (e) {
          reject(new Error('JSON parse error'));
        }
      } else {
        reject(new Error(err?.message || `HTTP ${data?.responseCode}`));
      }
      req.destroy();
    });
  });
}

// 通用 POST 请求
export function apiPost(path: string, body: object): Promise<object> {
  return new Promise((resolve, reject) => {
    let req = http.createHttp();
    req.request(BASE_URL + path, {
      method: http.RequestMethod.POST,
      header: { 'Content-Type': 'application/json' },
      extraData: JSON.stringify(body)
    }, (err, data) => {
      if (!err && data.responseCode === 200) {
        try {
          resolve(JSON.parse(data.result as string));
        } catch (e) {
          reject(new Error('JSON parse error'));
        }
      } else {
        reject(new Error(err?.message || `HTTP ${data?.responseCode}`));
      }
      req.destroy();
    });
  });
}

export { BASE_URL };