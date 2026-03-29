<template>
  <scroll-view class="setup-board" scroll-y="true">
    <!-- 标题 -->
    <view class="header">
      <text class="title">系统配置</text>
    </view>
	
    <!-- 1. 预设产品型号管理 -->
    <view class="config-card">
      <view class="card-header">
        <text class="card-title">📋 预设产品型号</text>
        <text class="card-desc">新增或修改产品对应的标准能效等级</text>
      </view>
      
      <view class="model-list">
        <view v-for="(item, index) in presetModels" :key="index" class="model-item">
          <view class="model-info">
            <text class="model-name">{{ item.name }}</text>
            <text class="model-desc">{{ item.model }}</text>
          </view>
          <view class="model-config">
            <text class="label">标准能效：</text>
            <picker :range="energyLevels" @change="(e) => updateModelLevel(index, e)">
              <view class="picker-value">{{ item.standardLabel }}</view>
            </picker>
          </view>
          <view class="model-status">
            <text class="label">启用：</text>
            <switch :checked="item.enabled" @change="(e) => toggleModel(index, e)" />
          </view>
        </view>
      </view>
      
      <view class="add-model">
        <input 
          v-model="newModel.name" 
          placeholder="请输入产品名称（如：冰箱）" 
          class="model-input"
        />
        <input 
          v-model="newModel.model" 
          placeholder="请输入产品型号（如：BCD-520W）" 
          class="model-input"
        />
        <picker :range="energyLevels" @change="onNewModelLevelChange">
          <view class="picker-btn">{{ newModel.standardLabel || '请选择能效等级' }}</view>
        </picker>
        <button class="add-btn" @click="addNewModel">➕ 添加</button>
      </view>
    </view>

    <!-- 2. 检测参数配置 -->
    <view class="config-card">
      <view class="card-header">
        <text class="card-title">⚙️ 检测参数</text>
        <text class="card-desc">调整检测灵敏度、容忍度等</text>
      </view>
      
      <!-- 位置检测容忍度 -->
      <view class="param-item">
        <view class="param-info">
          <text class="param-name">📍 位置偏移容忍度</text>
          <text class="param-desc">标签偏离中心多少%算异常</text>
        </view>
        <view class="param-control">
          <slider 
            :value="positionTolerance" 
            @change="(e) => positionTolerance = e.detail.value"
            min="0" max="20" step="1"
            style="width: 200px;"
          />
          <text class="param-value">{{ positionTolerance }}%</text>
        </view>
      </view>
      
      <!-- 缺陷检测灵敏度 -->
      <view class="param-item">
        <view class="param-info">
          <text class="param-name">🔍 缺陷检测灵敏度</text>
          <text class="param-desc">越高越容易检出微小缺陷</text>
        </view>
        <view class="param-control">
          <picker :range="sensitivityLevels" @change="(e) => sensitivity = sensitivityLevels[e.detail.value]">
            <view class="picker-value">{{ sensitivity }}</view>
          </picker>
        </view>
      </view>
      
      <!-- 光照补偿 -->
      <view class="param-item">
        <view class="param-info">
          <text class="param-name">💡 光照补偿</text>
          <text class="param-desc">适应不同环境光线</text>
        </view>
        <view class="param-control">
          <slider 
            :value="lightCompensation" 
            @change="(e) => lightCompensation = e.detail.value"
            min="-5" max="5" step="1"
            style="width: 200px;"
          />
          <text class="param-value">{{ lightCompensation > 0 ? '+' : '' }}{{ lightCompensation }}</text>
        </view>
      </view>
    </view>

    <!-- 3. 相机参数配置 -->
    <view class="config-card">
      <view class="card-header">
        <text class="card-title">📷 相机参数</text>
        <text class="card-desc">适应不同光照和拍摄距离</text>
      </view>
      
      <view class="param-item">
        <view class="param-info">
          <text class="param-name">🔆 曝光</text>
          <text class="param-desc">-3 到 +3</text>
        </view>
        <view class="param-control">
          <slider 
            :value="exposure" 
            @change="(e) => exposure = e.detail.value"
            min="-3" max="3" step="1"
            style="width: 200px;"
          />
          <text class="param-value">{{ exposure > 0 ? '+' : '' }}{{ exposure }}</text>
        </view>
      </view>
      
      <view class="param-item">
        <view class="param-info">
          <text class="param-name">📱分辨率</text>
        </view>
        <view class="param-control">
          <picker :range="resolutions" @change="(e) => resolution = resolutions[e.detail.value]">
            <view class="picker-value">{{ resolution }}</view>
          </picker>
        </view>
      </view>
    </view>

    <!-- 4. 保存按钮 -->
    <view class="save-section">
      <button class="save-btn" @click="saveConfig">💾 保存配置</button>
      <button class="reset-btn" @click="resetConfig">↺ 恢复默认</button>
    </view>
  </scroll-view>
</template>

<script>
export default {
  data() {
    return {
      // 能效等级选项
      energyLevels: ['A++', 'A+', 'A', 'B', 'C'],
      
      // 灵敏度选项
      sensitivityLevels: ['低', '中', '高'],
      
      // 分辨率选项
      resolutions: ['640x480', '1280x720', '1920x1080'],
      
      // 预设产品型号（初始默认值，后端加载成功后可以覆盖）
      presetModels: [
        { name: '冰箱', model: 'BCD-520W', standardLabel: 'A++', enabled: true }
      ],
      
      // 新增型号表单
      newModel: {
        name: '',
        model: '',
        standardLabel: 'A++'
      },
      
      // 检测参数
      positionTolerance: 10,
      sensitivity: '中',
      lightCompensation: 0,
      
      // 相机参数
      exposure: 0,
      resolution: '1280x720',

      // 后端默认配置备份（用于恢复默认时直接使用）
      defaultConfig: null
    }
  },
  
  onLoad() {
    this.fetchPresetData()
  },
  
  methods: {
    fetchPresetData() {
      uni.request({
        url: 'http://192.168.3.34:8000/api/config', // 替换为实际的API地址
        method: 'GET',
        success: (res) => {
          if (res.statusCode === 200) {
            const data = res.data
            this.presetModels = data.models || this.presetModels
            this.positionTolerance = data.positionTolerance || 10
            this.sensitivity = data.sensitivity || '中'
            this.lightCompensation = data.lightCompensation || 0
            this.exposure = data.camera?.exposure || 0
            this.resolution = data.camera?.resolution || '1280x720'

            // 备份后端默认配置，用于恢复默认时使用
            this.defaultConfig = {
              models: JSON.parse(JSON.stringify(this.presetModels)),
              positionTolerance: this.positionTolerance,
              sensitivity: this.sensitivity,
              lightCompensation: this.lightCompensation,
              camera: {
                exposure: this.exposure,
                resolution: this.resolution
              }
            }
          } else {
            console.error('获取预设数据失败', res)
          }
        },
        fail: (err) => {
          console.error('请求失败', err)
        }
      })
    },
    
    // 更新型号能效等级
    updateModelLevel(index, e) {
      const levelIndex = e.detail.value
      this.presetModels[index].standardLabel = this.energyLevels[levelIndex]
    },
    
    // 切换型号启用状态
    toggleModel(index, e) {
      this.presetModels[index].enabled = e.detail.value
    },
    
    // 新增型号的能效等级选择
    onNewModelLevelChange(e) {
      this.newModel.standardLabel = this.energyLevels[e.detail.value]
    },
    
    // 添加新型号
    addNewModel() {
      if (!this.newModel.name || !this.newModel.model) {
        uni.showToast({
          title: '请填写完整信息',
          icon: 'none'
        })
        return
      }
      
      this.presetModels.push({
        name: this.newModel.name,
        model: this.newModel.model,
        standardLabel: this.newModel.standardLabel,
        enabled: true
      })
      
      // 清空表单
      this.newModel = {
        name: '',
        model: '',
        standardLabel: 'A++'
      }
      
      uni.showToast({
        title: '添加成功',
        icon: 'success'
      })
    },
    
    // 保存配置
    saveConfig() {
      const configData = {
        models: this.presetModels,
        positionTolerance: this.positionTolerance,
        sensitivity: this.sensitivity,
        lightCompensation: this.lightCompensation,
        camera: {
          exposure: this.exposure,
          resolution: this.resolution
        }
      }
      
      uni.request({
        url: 'http://192.168.3.34:8000/api/config', // 替换为实际的API地址
        method: 'POST',
        data: configData,
        success: (res) => {
          if (res.statusCode === 200) {
            uni.showToast({
              title: '配置已保存',
              icon: 'success'
            })
            // 更新 defaultConfig 为最新保存值
            this.defaultConfig = JSON.parse(JSON.stringify(configData))
          } else {
            uni.showToast({
              title: '保存失败',
              icon: 'none'
            })
          }
        },
        fail: (err) => {
          console.error('保存请求失败', err)
          uni.showToast({
            title: '网络请求失败',
            icon: 'none'
          })
        }
      })
    },
    
    // 恢复默认
    resetConfig() {
      uni.showModal({
        title: '提示',
        content: '确定要恢复默认配置吗？',
        success: (res) => {
          if (res.confirm) {
            if (this.defaultConfig) {
              this.presetModels = JSON.parse(JSON.stringify(this.defaultConfig.models))
              this.positionTolerance = this.defaultConfig.positionTolerance
              this.sensitivity = this.defaultConfig.sensitivity
              this.lightCompensation = this.defaultConfig.lightCompensation
              this.exposure = this.defaultConfig.camera.exposure
              this.resolution = this.defaultConfig.camera.resolution

              // 发送恢复后的默认配置到后端
              uni.request({
                url: 'http://192.168.3.34:8000/api/config',
                method: 'POST',
                data: this.defaultConfig,
                success: (res) => {
                  if (res.statusCode === 200) {
                    uni.showToast({
                      title: '已恢复默认并同步后端',
                      icon: 'success'
                    })
                  } else {
                    uni.showToast({
                      title: '恢复失败',
                      icon: 'none'
                    })
                  }
                },
                fail: (err) => {
                  console.error('恢复请求失败', err)
                  uni.showToast({
                    title: '网络请求失败',
                    icon: 'none'
                  })
                }
              })

            } else {
              uni.showToast({
                title: '无默认数据可恢复',
                icon: 'none'
              })
            }
          }
        }
      })
    }
  },
  
  onLoad() {
    this.fetchPresetData()
  }
}
</script>

<style>
.setup-board {
  background-color: #f5f5f5;
  min-height: 150vh;
  font-family: Consolas;
}

.header {
  margin: 5px;
}

.title {
  font-size: 26px;
  font-weight: bold;
}

.config-card {
  background: white;
  border-radius: 16px;
  padding: 16px;
  margin-bottom: 16px;
  box-shadow: 1px 1px 1px 1px #808080;
}

.card-header {
  margin-bottom: 10px;
}

.card-title {
  font-size: 16px;
  font-weight: 600;
  color: #333;
}

.card-desc {
  font-size: 12px;
  color: #999;
  margin-top: 4px;
  display: block;
}

.model-list {
  border-radius: 8px;
  border: 2px dashed #808080;
  display: flex;
  flex-direction: column; 
  margin: 10px 0;
  padding: 12px;
  background-color:#ffffff;
}

.model-item {
  display: flex;
  align-items: center;
  padding: 8px 0;
  border-bottom: 1px solid #000000;
}

.model-info {
  width: 90px;
}

.model-name {
  font-size: 14px;
  font-weight: 500;
  display: block;
}

.model-desc {
  font-size: 12px;
  color: #999;
}

.model-config {
  flex: 1;
  display: flex;
  align-items: center;
  margin-left: 8px;
}

.model-status {
  display: flex;
  align-items: center;
  margin-left: 8px;
  min-width: 60px;
}

.label {
  font-size: 14px;
  color: #666;
  margin-right: 4px;
  width:50px;
}

.picker-value {
  background: #f0f0f0;
  padding: 6px 12px;
  border-radius: 16px;
  font-size: 14px;
  min-width: 40px;
  text-align: center;
}

.add-model {
  background: #f8f9fa;
  border-radius: 8px;
  padding: 12px;
  margin-top: 8px;
  border: 2px dashed #808080;
}

.model-input {
  background: white;
  border: 1px solid #ddd;
  border-radius: 8px;
  padding: 8px 12px;
  margin-bottom: 8px;
  font-size: 14px;
}

.picker-btn {
   background: white;
   border: 1px solid #ddd;
   border-radius: 8px;
   padding: 8px 12px;
   font-size: 14px;
   color: #666;
   text-align: center;
   margin-bottom: 8px;
}

.add-btn {
  background: #ffffff;
  border: 1px solid #808080;
  color:#666;
  border-radius: 8px;
  padding: 4px;
  font-size: 14px;
  width: 100%;
  height:40px;
}

.param-item {
  padding: 8px 0;
  border: 2px dashed #808080;
  border-radius:8px;
  margin:10px;
  display: flex;
  flex-direction: column;
}

.param-info {
  display:flex;
  flex-direction:column;
  margin-left:8px;
}

.param-name {
  font-size: 16px;
  font-weight: 500;
}

.param-desc {
  font-size: 12px;
  color: #999;
  margin-top: 2px;
}

.param-control {
  display: flex;
  align-items: center;
  justify-content: center;   
  gap: 8px;
  width: 100%;
  margin-bottom:8px;
}

.param-value {
  min-width: 40px;
  text-align: right;
  font-size: 16px;
  color: #333;
}

.save-section {
  display: flex;
  gap: 12px;
  margin: 10px 16px;
  height:50px;
}

.save-btn {
  flex: 2;
  background: #ffffff;
  border: 1px solid #808080;
  color:#666;
  border-radius: 12px;
  padding: 8px;
  font-size: 14px;
}

.reset-btn {
  flex: 1;
  background: #f0f0f0;
  color: #666;
  border: none;
  border-radius: 12px;
  padding: 8px;
  font-size: 14px;
}
</style>