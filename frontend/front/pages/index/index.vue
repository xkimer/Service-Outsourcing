<template>
 <scroll-view class="dashboard" scroll-y="true">
<!--标题-->
    <view class="header">
      <text class="title">生产线实时监控</text>
    </view>
<!--检测结果卡片-->
    <view class="result-card">
      <view class="status-badge" :class="currentResult.status">
        {{ currentResult.status === 'OK' ? '✓ 合格' : '✗ 不合格' }}
      </view>
<!--标签识别与校验-->
      <view :class="[ 'info-section', 'row-layout' ]">
        <image :src="currentResult.imageUrl" class="picture"></image>
        <view class="text">
        <text class="section-title">📋 标签识别</text>
        <view class="info-row">
          <text class="label">当前能效标签：</text>
          <text class="value highlight">{{ currentResult.ocrText }}</text>
        </view>
        <view class="info-row">
          <text class="label">预设型号：</text>
          <text class="value">{{ currentResult.presetModel }}</text>
        </view>
        <view class="info-row">
          <text class="label">比对结果：</text>
          <text :class="currentResult.isMatch">
            {{ currentResult.isMatch ? '✓ 匹配' : '✗ 不匹配' }}
          </text>
        </view>
      </view>
      </view>
<!--缺陷检测-->
      <view class="info-section">
        <text class="section-title">⚠️ 缺陷检测</text>
        <view class="defect-grid">
          <view class="defect-item" :class="{ 'has-defect': currentResult.defectType === '破损' }">
            <text>破损</text>
            <text class="defect-text" :class="currentResult.defectType">
              {{ currentResult.defectType === '破损' ? '✓有' : '○无' }}
            </text>
          </view>
          <view class="defect-item" :class="{ 'has-defect': currentResult.defectType === '污渍' }">
            <text>污渍</text>
            <text class="defect-text" :class="currentResult.defectType">
              {{ currentResult.defectType === '污渍' ? '✓有' : '○无' }}
            </text>
          </view>
          <view class="defect-item" :class="{ 'has-defect': currentResult.defectType === '褶皱' }">
            <text>褶皱</text>
            <text class="defect-text" :class="currentResult.defectType">
              {{ currentResult.defectType === '褶皱' ? '✓有' : '○无' }}
            </text>
          </view>
        </view>
      </view>
<!--位置检测-->
      <view class="info-section">
        <text class="section-title">📍 位置检测</text>
        <view class="info-row">
          <text class="label">粘贴位置：</text>
          <text :class="currentResult.positionStatus">
            {{ currentResult.positionStatus === '正常' ? '正常' : '存在问题' }}
          </text>
        </view>
<!--可视化的位置示意图-->
        <view class="position-visual">
          <view class="label-area" :style="{ left: currentResult.positionX + '%', top: currentResult.positionY + '%' }">
            📍
          </view>
        </view>
      </view>

<!--检测时间-->
      <view class="info-section">
        <text class="timestamp">⏱检测时间️： {{ currentResult.timestamp }}</text>
      </view>
<!--最近记录简表（时间、标签、检测总结果、标签缺陷检测、位置检测结果）-->
	<view class="info-section">
	<text class="list-title">📝 最近10条检测记录</text>
	<view class="type">
		<text class="type-time">时间</text>
		<text class="type-sign">型号</text>
		<text class="type-rst">结果</text>
		<text class="type-fault">缺陷</text>
		<text class="type-position">位置</text>
		</view>
	<view class="list-card">
      <view v-for="item in recentList" :key="item.id" class="list-item">
        <text class="item-time">{{ item.timestamp.slice(-8) }}</text>
        <text class="item-model">{{ item.productModel }}</text>
        <text class="item-stu" :class="item.status">{{ item.status ==='OK'? 'OK' : 'NG' }}</text>
        <text class="item-fault">{{ item.defectType }}</text>
        <text class="item-pos">{{ item.positionStatus }}</text>
      </view>
	  </view>
    <button class="recent-btn" @click="goToHistory">查看更多</button>
    </view>
	</view>
  </scroll-view>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import{ onShow } from '@dcloudio/uni-app'

//跳转页面
const goToHistory=()=>{
	uni.navigateTo({
		url:'/pages/history/history',
		success:(res)=>{
			console.log('跳转成功');
		},
	fail:(err)=>{
		console.error('跳转失败',err);
		uni.showToast({
			title:'页面不存在',
			icon:'none'
		});
	}
	});
}

// 当前检测结果（初始状态不使用假数据）
const currentResult = ref({
  status: '',
  ocrText: '',
  presetModel: '',
  isMatch: false,
  hasDefect: false,
  defectType: null,
  positionStatus: '',
  positionX: '0',
  positionY: '0',
  timestamp: '',
  imageUrl: ''
})

// 最近记录列表
const recentList = ref([])

// 获取当前检测结果
const fetchCurrentResult = () => {
  uni.request({
    url: 'http://192.168.3.34:8000/api/current', // 替换为实际的API地址
    method: 'GET',
    success: (res) => {
      if (res.statusCode === 200 && res.data) {
        currentResult.value = {
          ...res.data,
          timestamp: new Date().toLocaleTimeString()
        }
      } else {
        console.error('获取当前结果失败', res)
      }
    },
    fail: (err) => {
      console.error('请求失败', err)
    }
  })
}

// 获取最近记录
const fetchRecentRecords = () => {
  uni.request({
    url: 'http://192.168.31.95:8000/api/recent', // 替换为实际的API地址
    method: 'GET',
    data: { limit: 10 },
    success: (res) => {
      if (res.statusCode === 200 && res.data) {
        recentList.value = res.data.map((item, index) => ({
          id: `recent_${index}`,
          timestamp: item.timestamp || new Date().toLocaleTimeString(),
          productModel: item.presetModel,
          ocrText: item.ocrText,
          status: item.status,
          defectType: item.defectType,
          positionStatus: item.positionStatus
        }))
      } else {
        console.error('获取最近记录失败', res)
      }
    },
    fail: (err) => {
      console.error('请求失败', err)
    }
  })
}

// 刷新数据
const refreshData = () => {
  fetchCurrentResult()
  fetchRecentRecords()
}

// 页面加载时
onMounted(() => {
  console.log('页面加载成功')
  refreshData()
})

// 页面显示时刷新数据
onShow(() => {
  refreshData()
})
</script>
<!--页面样式-->
<style>
.dashboard {      
  font-family: Consolas;
  height:145vh;
  overflow-y:auto;
  background-color:#eee;
}
.header {
  margin:5px;
}
.title {
   font-size:26px;
   font-weight:bold;
   margin:5px;
}
.result-card {
  background-color: #ffffff;
  color: #000000;
  font-family: Consolas;
  border-radius: 16px;
  padding: 16px;
  margin: 5px 0 10px 0;
  box-shadow: 1px 1px 1px 1px #808080;
  border:1px solid #ffffff;
}
.status-badge {
  font-size: 20px;
  font-weight: bold;
  margin-bottom: 5px;
  color:#000000;
}
.info-section {
  border-radius: 8px;
  border: 2px dashed #808080;
  display: flex;
  flex-direction: column; 
  margin: 10px 0;
  padding: 12px;
  background-color:#ffffff;
}
.row-layout {
  flex-direction:row; 
  align-items:flex-start;
}
.picture {
   width: 45%; 
   height:90%;
   border-radius: 4px;
   flex-shrink:0;
   margin:8px;
}
.text {
   flex:1;
   display:flex;
   flex-direction:column;
}
.section-title {
  font-size: 16px;
  font-weight: 600;
  margin-bottom: 8px;
}
.value { 
   flex: 1; 
}
.highlight { 
  font-size: 18px; 
  font-weight: bold;
}
.defect-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
  margin-top: 8px;
}
.defect-item {
  display: flex;
  justify-content: center;
  align-items: center;
  text-align: center;
  padding: 2px;
  min-height: 35px;
  background: #ffffff;
  color: #000000;
  border-radius: 8px;
  border: 2px solid #ccc;
  line-height: 1.2;
}
.defect-text {
  margin-left:3px;
}
.defect-item.has-defect {
  border-color: #f44336;
}

.item-pos {
  text-align: center;
  width:50px;

}

.position-visual {
  position: relative;
  width: 100%;
  height: 100px;
  background: #eee;
  border: 2px dashed #ccc;
  margin-top: 8px;
}
.label-area {
  position: absolute;
  width: 30px;
  height: 30px;
  transform: translate(-50%, -50%);
}
.list-title {
	margin-bottom:5px;
}
.type {
  display: flex;
  align-items: center;
  justify-content: flex-start;
  gap: 3px;
  margin: 2px 0;
}
.type-time {
  width: 60px;
  text-align: center;
}
.type-sign {
  width: 80px;
  text-align: center;
}
.type-rst {
  width: 50px;
  text-align: center;
}
.type-fault {
  width: 50px;
  text-align: center;
}
.type-position {
  width: 50px;
  text-align: center;
}
.list-card{
  margin:2px 0;
}
.list-item {
  display: flex;
  align-items: center;
  padding: 8px 0;
  border-bottom: 1px solid #000000;
  gap: 3px;
}
.item-time { 
   width: 60px; 
   color: #b3b3b3; 
}
.item-model { 
   width: 80px; 
   text-align: center;
}
.item-label { 
   width: 50px; 
   text-align: center; 
}
.item-stu {
   width: 50px;
   text-align: center;
}
.item-stu.OK {
   color:#000000;
}
.item-stu.NG {
   color:#ff0000;
}
.item-fault {
  width:50px; 
  text-align: center;
}
.item-pos {
   width:50px;
   text-align: center;
}
.recent-btn {
  background-color:#FFFFFF;
  color:#000000;
  border-radius:12px;
  height:38px;
  width:120px;
  border: 1px solid #ccc;
  margin-top:8px;
  padding:2px;
  font-size:14px;
}
</style>