<template>
  <!--历史记录页面-->
  <scroll-view class="historyboard" scroll-y="true">
    <!--标题-->
    <view class="title">历史检测记录</view>
    <view class="intro">⏱️仅显示近一个月的数据</view>

    <!--筛选栏-->
    <view class="list-card">
      <view class="choice">
        <button @click="clearFilters" class="all-btn">📄️ 全部</button>

        <picker @change="filterByDate" mode="date" :start="minDate" :end="maxDate" class="pick">
          <view class="choice-btn">📅 按日期筛选</view>
        </picker>

        <picker @change="filterByStatus" :range="statusOptions" range-key="label" class="pick">
          <view class="choice-btn">⭕ 按状态筛选</view>
        </picker>
      </view>
    </view>

    <!--记录列表卡片-->
    <view class="list-card">
      <text class="list-title">📋 检测记录</text>

      <view class="list-data">
        <view class="type">
          <text class="type-num">序号</text>
          <text class="type-time">时间</text>
          <text class="type-sign">型号</text>
          <text class="type-rst">结果</text>
          <text class="type-fault">缺陷</text>
        </view>

        <view v-for="(item,index) in completeList" :key="item.id" class="list-item">
          <text class="number">{{ (currentPage-1)*pageSize + index + 1 }}</text>
          <text class="item-time">{{ formatTime(item.timestamp) }}</text>
          <text class="item-model">{{ item.productModel || '--' }}</text>
          <text class="item-label">{{ item.ocrText }}</text>
          <text class="item-stu" :class="item.status">{{ item.status === 'OK' ? 'OK' : 'NG' }}</text>
          <text v-if="item.defectType" class="defect-badge">{{ item.defectType }}</text>
        </view>

        <!--加载与结束状态-->
        <view class="load-more" v-if="completeList.length > 0">
          <text v-if="loading">加载中...</text>
          <text v-else-if="noMore">--- 没有更多了 ---</text>
        </view>

        <!--无检测记录的情况-->
        <view class="empty-state" v-if="completeList.length === 0 && !loading">
          <text>-- 暂无检测记录 --</text>
        </view>

        <!--分页信息-->
        <view class="page-info" v-if="totalPages>1">
          <view class="page-btns">
            <button class="page-btn" @click="prePage" :disabled="currentPage === 1 || loading"><</button>
            <text class="page-status">第 {{ currentPage }}/{{ totalPages }} 页</text>
            <button class="page-btn" @click="nextPage" :disabled="currentPage === totalPages || loading">></button>
            <text class="page-total">共 {{ totalRecords }} 条</text>
          </view>
        </view>
      </view>
    </view>
  </scroll-view>
</template>

<script>
export default {
  data() {
    const today = new Date();
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(today.getDate() - 30);

    const formatDate = (date) => {
      const y = date.getFullYear();
      const m = String(date.getMonth() + 1).padStart(2, '0');
      const d = String(date.getDate()).padStart(2, '0');
      return `${y}-${m}-${d}`;
    };

    return {
      allHistory: [],
      completeList: [],
      currentPage: 1,
      pageSize: 25,
      loading: false,
      noMore: false,
      totalRecords: 0,
      totalPages: 0,
      currentStatusFilter: { label: '全部记录', value: 'ALL' },
      currentDateFilter: '',
      statusOptions: [
        { label: '全部记录', value: 'ALL' },
        { label: '合格 OK', value: 'OK' },
        { label: '不合格 NG', value: 'NG' }
      ],
      minDate: formatDate(thirtyDaysAgo),
      maxDate: formatDate(today)
    }
  },

  onShow() {
    this.loadPage();
  },

  methods: {
    // 通用加载当前页
    loadPage() {
      this.loading = true;
      const today = new Date();
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(today.getDate() - 30);

      uni.request({
        url: 'http://192.168.3.34:8000/api/history', // 替换为实际API
        method: 'GET',
        data: {
          page: this.currentPage,
          pageSize: this.pageSize,
          startDate: this.currentDateFilter || thirtyDaysAgo.toISOString().split('T')[0],
          endDate: today.toISOString().split('T')[0],
          statusFilter: this.currentStatusFilter.value
        },
        success: (res) => {
          this.loading = false;
          if (res.statusCode === 200 && res.data) {
            this.allHistory = res.data.records || [];
            this.totalRecords = res.data.total || 0;
            this.totalPages = Math.ceil(this.totalRecords / this.pageSize);

            this.completeList = [...this.allHistory];
            this.noMore = this.currentPage >= this.totalPages;
          } else {
            uni.showToast({ title: '获取数据失败', icon: 'none' });
          }
        },
        fail: () => {
          this.loading = false;
          uni.showToast({ title: '网络请求失败', icon: 'none' });
        }
      });
    },

    prePage() {
      if (this.currentPage > 1 && !this.loading) {
        this.currentPage--;
        this.loadPage();
      }
    },

    nextPage() {
      if (this.currentPage < this.totalPages && !this.loading) {
        this.currentPage++;
        this.loadPage();
      }
    },

    formatTime(timestamp) {
      const date = new Date(timestamp);
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      const hour = String(date.getHours()).padStart(2, '0');
      const minute = String(date.getMinutes()).padStart(2, '0');
      return `${month}-${day} ${hour}:${minute}`;
    },

    filterByStatus(e) {
      const index = e.detail.value;
      this.currentStatusFilter = this.statusOptions[index];
      this.currentPage = 1;
      this.loadPage();
    },

    filterByDate(e) {
      const selectedDate = e.detail.value;
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
      const minDate = thirtyDaysAgo.toISOString().split('T')[0];

      if (selectedDate < minDate) {
        uni.showToast({ title: '只能查看最近30天的记录', icon: 'none' });
        return;
      }

      this.currentDateFilter = selectedDate;
      this.currentPage = 1;
      this.loadPage();
    },

    clearFilters() {
      this.currentStatusFilter = { label: '全部记录', value: 'ALL' };
      this.currentDateFilter = '';
      this.currentPage = 1;
      this.loadPage();
    }
  }
}
</script>

<style> 
.historyboard { 
	font-family: Consolas; 
	height: 145vh; 
    background-color: #eee; 
	} 
.title { 
	font-size: 26px; 
	font-weight: bold; 
	margin: 5px; 
	} 
.intro { 
	font-size:14px; 
	color:#808080; 
	margin:5px; 
	background-color:#ffffff; 
	border-radius:10px; 
	padding:2px 4px; 
	width:165px; 
	} 
.choice { 
	display: flex; 
	gap: 0; 
	margin: 5px; 
	border: 2px dashed #808080; 
	border-radius: 8px; 
	height: 50px; /* 保持固定高度，确保格子一致 */ 
	box-sizing: border-box; 
	align-items: stretch; 
	} /* 子元素不圆角，避免分隔线看起来弯 */ 
.choice > * { 
	border-radius: 0; 
	box-sizing: border-box; 
	} /* 左右两端保留外框圆角 */ 
.choice > *:first-child { 
	border-top-left-radius: 8px; 
	border-bottom-left-radius: 8px; 
	} 
.choice > *:last-child { 
	border-top-right-radius: 8px; 
	border-bottom-right-radius: 8px; 
	} /* 让每个区块之间有虚线分隔（最后一个不需要） 线条粗细与外框一致 */ 
.choice > *:not(:last-child) { 
	border-right: 2px dashed #808080; 
	} 
.all-btn { 
	font-size: 12px; 
	border: none; /* 移除边框 */ 
	outline: none; 
	background-color: transparent; 
	margin: 0; /* 移除margin，使用padding控制 */ 
	padding: 0; 
	text-align: center; 
	flex: 0 0 20%; /* 保持20%宽度 */
	height: 100%; 
	min-width: 0; 
	display: flex; 
	align-items: center; 
	justify-content: center; 
	box-sizing: border-box; 
	} 
.pick { 
	flex: 0 0 40%; /* 保持40%宽度 */ 
	height: 100%; 
	min-width: 0; 
	display: flex; 
	align-items: center; 
	justify-content: center; 
	box-sizing: border-box;
	 } 
.choice-btn { 
	background-color: transparent; 
	padding: 0 8px; 
	font-size: 14px; 
	color: #666; 
	border: none; /* 移除边框 */ 
	outline: none; 
	height: 100%; 
	width: 100%; 
	line-height: 50px; 
	text-align: center; 
	display: flex; 
	align-items: center; 
	justify-content: center; 
	box-sizing: border-box;
	 } 
.list-card { 
	background-color: #ffffff; 
	color: #000000; 
	font-family: Consolas;
	border-radius: 16px; 
	padding: 16px; 
	margin: 5px 0 10px 0; 
	box-shadow: 1px 1px 1px 1px #808080; 
	border: 1px solid #ffffff; 
	} 
.list-title { 
	margin-bottom:10px; 
	} 
.type { 
	display:flex; 
	align-items: center; 
	justify-content: flex-start;
	text-align:center; 
	gap:2px; 
	} 
.type-num { 
	width:35px; 
	text-align:center; 
	} 
.type-time { 
	width: 60px; 
	text-align: center; 
	} 
.type-sign { 
	width: 60px; 
	text-align: center;
	 } 
.type-rst { 
	width: 45px; 
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
.list-data { 
	border-radius: 8px; 
	border: 2px dashed #808080; 
	display: flex; 
	flex-direction: column; 
	margin: 2px 0; 
	padding: 12px; 
	background-color: #ffffff;
	 } 
.list-item { 
	display: flex; 
	align-items: center;
	padding: 8px 0; 
	border-bottom: 1px solid #000000; 
	} 
.number { 
	width:25px; 
	border-radius:50%;
	border:1px solid #ffffff; 
	background-color:#eee; 
	padding:1px; 
	text-align:center; 
	margin-right:15px; 
	} 
.item-time { 
	width:60px; 
	color:#b3b3b3;
	} 
.item-model { 
	width: 60px; 
	text-align: center; 
	} 
.item-label { 
	width:45px; 
	text-align: center; 
	} 
.item-stu { 
	width:50px; 
	text-align: center; 
	} 
.item-stu.OK { 
	color:#000000; 
	} 
.item-stu.NG {
	color:#ff0000; 
	} 
.defect-badge { 
	width:50px; 
	text-align:center;
	 } 
.load-more { 
	text-align:center;
	color:#b3b3b3;
	margin:5px; 
	} 
.empty-state{ 
	color:#808080; 
	text-align:center;
	margin:5px; 
	} 
.page-info { 
	text-align:center; 
	margin-top:5px; 
	} 
.page-btns { 
	margin:10px; 
	display:flex; 
	text-align:center; 
	justify-content:center; 
	height:50px; 
	} 
.page-btn { 
	font-size:12px; 
	border-radius:50%; 
	background-color:#eee; 
	margin:5px; 
	padding:1px; 
	text-align:center; 
	width:30px; 
	} 
.page-btn:disabled { 
	curser:not-allowed;
	background:#ccc; 
	} 
.page-status { 
	margin-top:10px; 
	} 
.page-total { 
	margin-left:10px;
	margin-top:10px;
	} 
</style>