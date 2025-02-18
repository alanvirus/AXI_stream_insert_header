# AXI Stream Insert Header 

本项目实现了一个 **AXI Stream Insert Header** 模块，该模块的主要功能是将头部信息插入到 AXI stream数据流中。

## 文件说明

- **主模块**:
  - `src/axi_stream_insert_header.sv`：功能实现部分。

- **内部子模块**:
  - `src/data_combiner.sv`：数据拼接模块，负责主模块内部的数据拼接。
  - `src/skid_buffer.sv`：skid_buffer模块,保证逐级背压。
  - 
- **测试用模块**:
  - `src/test_master.sv`：生成符合AXIstream协议要求的输入数据。

- **测试文件**:
  - `sim/axi_stream_insert_header_tb.sv`：生成随机化激励，具体激励方式见仿真报告。
  
- **波形文件**:
  - `sim/axi_stream_insert_header_tb_behav_HEADER_NUM_2.wcfg`:两次请求版本
  - `sim/axi_stream_insert_header_tb_behav_HEADER_NUM_3.wcfg`:三次请求版本

- **仿真报告**:
  - `simulation_report.pdf`：仿真报告描述了仿真架构、激励设计以及验证的各种情形。通过网址 https://deadpan-suede-0e1.notion.site/simulation-report-19dbf202d44f8051bebef07c5acb8060?pvs=4 可访问在线版本，格式更美观。


