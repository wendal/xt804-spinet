# xt804-spinet
把xt804当网卡用, SPI接口的, 适用于Air601/W800/W803

**正在努力实现中, 还未完全跑通**

## 工作原理简介

1. Air601是支持SPI从机的, 最高50M
2. Air780E等支持SPI主机, 其中Air780E最高25.6M, Air780EP最高51.2M

## 接线说明

|Air780E         |Air601|说明           |
|----------------|------|---------------|
|3.3v            | 3.3v | 电源          |
|GND             | GND  | 地            |
|SPI0_CS/GPIO8   | PB09 | 片选          |
|SPI0_MOSI/GPIO  | PB10 | 主->从,数据下行|
|SPI0_MISO       | PB11 | 主<-从,数据上行|
|SPI0_CLK        | PB06 | SPI时钟|

## 目录说明

1. 4g 目录, 给Air780E/Air780EG/Air780EP用的脚本
2. wifi 目录, 给Air601用的脚本
3. soc 目录, 测试固件, 搭配脚本刷机
4. doc 目录, 文档

## LICENSE

MIT
