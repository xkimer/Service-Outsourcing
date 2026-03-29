<template>
  <scroll-view class="statistic-board" scroll-y="true">
    <!-- 标题 -->
    <view class="header">
      <text class="title">今日统计报表</text>
    </view>
    <view class="chart-card">
    <!-- 1. 折线图 - 近7天检测趋势 -->
    <view class="chart-pic">
      <text class="chart-title">📈 最近7天检测趋势</text>
      <view class="chart-container">
		<view class="color-sign">
		      <view v-for="(series, index) in trendData.series" :key="index" class="sign-item">
		        <view class="color-tangle" :style="{ backgroundColor: lineOpts.color[index] }"></view>
		        <text class="sign-name">{{ series.name }}</text>
		      </view>
		    </view>
        <qiun-data-charts 
          type="line"
          :chartData="trendData"
          :opts="lineOpts"
          :width="width"
          :height="height"
        />
      </view>
    </view>
    
    <!-- 2. 饼图 - 缺陷分布 -->
    <view class="chart-pic">
      <text class="chart-title">🍕 不合格类型分布</text>
      <view class="chart-container">
		  <view class="color-sign">
        <text class="pie-name">标签缺陷分布</text>
		        <view v-for="(series, index) in pieData.series[0].data" :key="index" class="sign-item">
		          <view class="color-tangle" :style="{ backgroundColor: pieOpts.color[index] }"></view>
		          <text class="sign-name">{{ series.name }}</text>
		  		  <text style="margin-left:3px">{{ series.value }}</text>
		        </view>
		      </view>
        <qiun-data-charts 
          type="pie"
          :chartData="pieData"
          :opts="pieOpts"
          :width="width"
          :height="height"
        /> 
        <view class="color-sign">
          <text class="pie-name">位置缺陷分布</text>
		        <view v-for="(series, index) in pieData2.series[0].data" :key="index" class="sign-item">
		          <view class="color-tangle" :style="{ backgroundColor: pieOpts2.color[index] }"></view>
		          <text class="sign-name">{{ series.name }}</text>
		  		  <text style="margin-left:3px">{{ series.value }}</text>
		        </view>
		      </view>
        <qiun-data-charts 
          type="pie"
          :chartData="pieData2"
          :opts="pieOpts2"
          :width="width"
          :height="height"
        />
      </view>
    </view>
    
    <!-- 3. 柱状图 - 各型号合格率 -->
    <view class="chart-pic">
      <text class="chart-title">📊 各型号合格率</text>
      <view class="chart-container">
        <qiun-data-charts 
          type="bar"
          :chartData="barData"
          :opts="barOpts"
          :width="width"
          :height="height"
        />
      </view>
    </view>
	</view>
  </scroll-view>
</template>

<script>
import qiunDataCharts from '@/uni_modules/qiun-data-charts/components/qiun-data-charts/qiun-data-charts.vue'
export default {
  components: { qiunDataCharts },
  data() {
    return {
      currentDate: '',
      width: '100%',
      height: '250px',
      totalDefects: 200,
      
      // 折线图数据
      trendData: {
        categories: ['03-01', '03-02', '03-03', '03-04', '03-05', '03-06', '03-07'],
        series: [
          {
            name: '检测总数',
            data: [85, 92, 88, 95, 102, 98, 110]
          },
		  { 
			name: '缺陷总数',
			data: [5,8,7,4,6,9,9]
		  }
        ]
      },
      lineOpts: {
        color: ['#4A90E2','#ff0000'],
        padding: [20, 15, 15, 10],
        xAxis: {
          disableGrid: false,
          gridType: 'dash',
          axisLine: { show: true },
          labelRotation: 0,
		  itemGap: 5,
		  fontSize:10
        },
        yAxis: {
          gridType: 'dash',
          splitNumber: 5,
          min: 0,
          max: 120
        },
        legend: {
          show: false
        },
        dataLabel: {
          show: true,
          position: 'top'
        }
      },
      
      // 饼图数据
      pieData: {
        series: [{
          name: '缺陷类型',
          data: [
            { name: '破损', value: 23 },
            { name: '污渍', value: 18 },
            { name: '褶皱', value: 12 },
            { name: '正常', value: 139 }
          ]
        }]
      },
      pieOpts: {
        color: ['#FF6B6B', '#4ECDC4', '#45B7D1', '#FFEEAD'],
        legend: {
          show: false
        },
        extra: {
          pie: {
            offsetAngle: -90,
            ringWidth: 30,
            labelWidth: 15
          }
        },
        dataLabel: {
          show: true,
          position: 'outside'
        }
      },
      pieData2: {
        series: [{
          name: '位置类型',
          data: [
            { name: '偏左', value: 23 },
            { name: '偏右', value: 18 },
            { name: '偏上', value: 12 },
            { name: '偏下', value: 15 },
            { name: '正常', value: 124 }
          ]
        }]
      },
      pieOpts2: {
        color: ['#FF6B6B', '#4ECDC4', '#45B7D1', '#FFEEAD', '#50C878'],
        legend: {
          show: false
        },
        extra: {
          pie: {
            offsetAngle: -90,
            ringWidth: 30,
            labelWidth: 15
          }
        },
        dataLabel: {
          show: true,
          position: 'outside'
        }
      },
      // 柱状图数据
      barData: {
        categories: ['冰箱', '空调', '洗衣机', '电视', '微波炉'],
        series: [{
          name: '合格率 (%)',
          data: [98, 95, 97, 94, 92]
        }]
      },
      barOpts: {
        color: ['#50C878'],
        padding: [15, 20, 15, 15],
        yAxis: {
          min: 0,
          max: 100,
          splitNumber: 5,
          gridType: 'dash',
		  position: 'right'
        },
        xAxis: {
          axisLine: { show: true },
          labelRotation: 0,
		  fontSize:12
        },
        dataLabel: {
          show: true,
          position: 'right',
          color: '#333'
        },
        legend: {
          show: false
        }
      }
    }
  },
  
  computed: {
    rankData() {
      // 从 barData 生成排名数据
      const models = this.barData.categories.map((model, index) => ({
        model: model,
        rate: this.barData.series[0].data[index] || 0
      }))
      return models.sort((a, b) => b.rate - a.rate)
    }
  },
  
  onLoad() {
    this.fetchStatistics()
  },
  
methods: {
  getLast7Days() {
    const days = []
    const now = new Date()
    for (let i = 6; i >= 0; i--) {
      const d = new Date(now)
      d.setDate(now.getDate() - i)
      const yy = d.getFullYear()
      const mm = String(d.getMonth() + 1).padStart(2, '0')
      const dd = String(d.getDate()).padStart(2, '0')
      days.push(`${yy}-${mm}-${dd}`)
    }
    return days
  },

  fetchStatistics() {
    const now = new Date()
    const endDate = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
    const startDateObj = new Date(now)
    startDateObj.setDate(now.getDate() - 6)
    const startDate = `${startDateObj.getFullYear()}-${String(startDateObj.getMonth() + 1).padStart(2, '0')}-${String(startDateObj.getDate()).padStart(2, '0')}`

    uni.request({
      // ⚠️ 这里先别用 /docs！！！！
      url: 'http://192.168.3.34:8000/api/statistic', 
      method: 'GET',
      data: {
        startDate,
        endDate
      },
      success: (res) => {
        console.log('接口返回：', res)

        if (res.statusCode === 200 && res.data) {
          this.processData(res.data)
        } else {
          console.error('获取数据失败', res)
          uni.showToast({
            title: '获取数据失败',
            icon: 'none'
          })
        }
      },
      fail: (err) => {
        console.error('请求失败', err)
        uni.showToast({
          title: '网络请求失败',
          icon: 'none'
        })
      }
    })
  },

  processData(data) {
    const last7Days = this.getLast7Days()

    const dayStats = {}
    last7Days.forEach(day => {
      dayStats[day] = { total: 0, defects: 0 }
    })

    const defectCounts = { '正常': 0, '破损': 0, '污渍': 0, '褶皱': 0 }
    const positionCounts = { '正常': 0, '偏左': 0, '偏右': 0, '偏上': 0, '偏下': 0 }
    const modelStats = {}

    data.forEach(item => {
      const ts = item.timestamp || item.time || item.createTime || ''
      const dt = ts ? new Date(ts) : null
      if (!dt || Number.isNaN(dt.getTime())) return

      const Y = dt.getFullYear()
      const M = String(dt.getMonth() + 1).padStart(2, '0')
      const D = String(dt.getDate()).padStart(2, '0')
      const dateKey = `${Y}-${M}-${D}`

      if (!dayStats[dateKey]) return

      dayStats[dateKey].total++
      if (item.hasDefect || item.defectType) {
        dayStats[dateKey].defects++
      }

      if (item.defectType) {
        defectCounts[item.defectType] = (defectCounts[item.defectType] || 0) + 1
      } else {
        defectCounts['正常']++
      }

      if (item.positionStatus) {
        positionCounts[item.positionStatus] = (positionCounts[item.positionStatus] || 0) + 1
      }

      const model = item.presetModel || '未知'
      if (!modelStats[model]) {
        modelStats[model] = { total: 0, ok: 0 }
      }
      modelStats[model].total++
      if (item.status === 'OK') {
        modelStats[model].ok++
      }
    })

    // 折线图
    this.trendData.categories = last7Days.map(d => d.slice(5))
    this.trendData.series[0].data = last7Days.map(d => dayStats[d].total)
    this.trendData.series[1].data = last7Days.map(d => dayStats[d].defects)

    // 饼图
    this.pieData.series[0].data = Object.entries(defectCounts).map(
      ([name, value]) => ({ name, value })
    )

    this.pieData2.series[0].data = Object.entries(positionCounts).map(
      ([name, value]) => ({ name, value })
    )

    // 柱状图
    this.barData.categories = Object.keys(modelStats)
    this.barData.series[0].data = Object.values(modelStats).map(stat =>
      stat.total > 0 ? Math.round((stat.ok / stat.total) * 100) : 0
    )
  },

  getRankColor(index) {
    const colors = ['#FFD700', '#C0C0C0', '#CD7F32', '#4A90E2', '#999']
    return colors[index] || '#4A90E2'
  }
  }
}
</script>

<style>
.statistic-board {
  background-color: #f5f5f5;
  min-height: 145vh;
  font-family: Consolas;
}
.header {
  margin:5px;
}
.title {
  font-size: 26px;
  font-weight: bold;
}
.chart-card {
  background: #ffffff;
  border-radius: 16px;
  padding: 16px;
  margin:5px 0 10px 0;
  box-shadow: 1px 1px 1px 1px #808080;
}
.chart-title {
  font-size: 16px;
  font-weight: 500;
  margin: 10px;
  display: block;
}
.chart-container {
 border-radius: 8px;
 border: 2px dashed #808080; 
 margin: 10px 0;
 padding: 12px;
 background-color:#ffffff;
}
.color-sign {
	margin: 5px;
	display: flex;
	flex-direction: row;        
	flex-wrap: wrap;            
	gap: 8px 5px;             
	padding: 8px;
	background: #f8f9fa;
	border-radius: 8px;
	width:50%;
}
.sign-item {
	display: flex;
	align-items: center;
	white-space: nowrap;
	width: calc(50% - 8px);
	font-size:12px;
}
.color-tangle {
	width:10px;
	height:3px;
	margin-right:3px;
}
</style>