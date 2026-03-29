<template>
  <view class="home-board">
	  <view class="header">
		  <text class="title">能效标签检测系统</text>
		  <text class="date">{{ currentDate }}</text>
	  </view>
	  <view class="btn-card">
		  <view class="welcome-text">
			  <text style="font-weight:600;margin-bottom:5px;color:#000000">🎉欢迎使用能效标签检测APP!🎉</text><text style="line-height:1.6;color: #555555">  本APP主要作用于识别家电产品型号，并实时反馈该产品标签的缺陷与位置情况，使用前请先进入<text class="highlight">系统配置页</text>进行相关配置，祝您获得愉快的使用体验！</text>
		  </view>
		  <view class="enter">➡️️页面入口</view>
		  <view class="page-btns">
		  <button class="page-btn" @click="goToPage('index')">🔬  当前检测结果
		  </button>
		  <button class="page-btn" @click="goToPage('history')">🎞️️  历史记录查询
		  </button>
		  <button class="page-btn" @click="goToPage('statistic')">📉  今日统计报表
		  </button>
		  <button class="page-btn" @click="goToPage('setup')">⚙️️  系统配置/扩展
	      </button>
  </view>
  </view>
  </view>
</template>

<script>
export default {
	  data() {
	    return {
	      currentDate: ''
	    }
	  },
	  onShow() {
	    const date = new Date();
	    const year = date.getFullYear();
	    const month = String(date.getMonth() + 1).padStart(2, '0');
	    const day = String(date.getDate()).padStart(2, '0');
	    this.currentDate = `${year}-${month}-${day}`;
	  },
   methods: {
	   goToPage(page) {
		   uni.navigateTo ({
			   url: `/pages/${page}/${page}`
		   });
	   }
   }
}
</script>

<style>
.home-board {
	background-color:#eee;
	font-family: Consolas;
	overflow-y:auto;
	height:145vh;
}
.header {
	margin:10px;
	display:flex;
	justify-content:space-between;
	width:100%;
	align-items:center;
}
.title {
	font-size:26px;
	font-weight:bold;
	margin:5px;
}
.date {
   color: #D3D3D3;
   font-size:16px;
   margin-right:15px;
}
.welcome-text {
	border-radius: 8px;
	border: 2px dashed #808080;
	display: flex;
	flex-direction: column; 
	margin: 10px 0;
	padding: 16px;
	text-align:center;
}
.highlight {
	background-color:#e0ffff;
	margin:0 2px;
	border-radius:4px;
	padding:2px 4px;
}
.enter {
	margin:10px 0 5px 0;
}
.btn-card {
	background-color: #ffffff;
	color: #000000;
	border-radius: 16px;
	padding: 16px;
	margin: 5px 0 10px 0;
	box-shadow: 1px 1px 1px 1px #808080;
	border: 1px solid #ffffff;
}
.page-btns {
	border-radius: 8px;
	border: 2px dashed #808080;
	display: flex;
	flex-direction: column; 
	margin: 10px 0;
	padding: 0;
}
.page-btn {
	background-color:#ffffff;
	width:100%;
	border:none;
	border-buttom:1px solid #b3b3b3;
	font-size:16px;
	padding:5px;
	margin:0;
}
</style>