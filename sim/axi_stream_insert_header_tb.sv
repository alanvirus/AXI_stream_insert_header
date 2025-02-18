`timescale 1ns / 1ps
module axi_stream_insert_header_tb;

    parameter DATA_WD = 32;
    parameter DATA_BYTE_WD = DATA_WD / 8;
    parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD);
    parameter HEADER_NUM = 3;//传输数据流的总数
    parameter AVG_LENGTH = 3;//数据流的平均帧长度
    parameter DATA_NUM = HEADER_NUM*AVG_LENGTH;//数据帧的总数
    parameter NO_INTERRUPT = 0;//是否连续发送，如果为1则连续发送，如果为0则发送之间停顿随机时间
    
    integer seed_value;

    reg clk;
    reg rst_n;

    logic valid_in;
    logic [DATA_WD-1:0] data_in;
    logic [DATA_BYTE_WD-1:0] keep_in;
    logic last_in;
    wire ready_in;

    reg [DATA_WD-1:0] data_in_test [0:DATA_NUM-1];
    reg [DATA_BYTE_WD-1:0] keep_in_test [0:DATA_NUM-1];
    reg last_in_test [0:DATA_NUM-1];
    reg ramdom_delay;


    logic valid_insert;
    logic [DATA_WD-1:0] data_insert;
    logic [DATA_BYTE_WD-1:0] keep_insert;
    wire ready_insert;

    reg [DATA_WD-1:0] data_header_test [0:HEADER_NUM-1];
    reg [DATA_BYTE_WD-1:0] keep_header_test [0:HEADER_NUM-1];
    reg ramdom_delay_2;

    wire valid_out;
    wire [DATA_WD-1:0] data_out;
    wire [DATA_BYTE_WD-1:0] keep_out;
    wire last_out;
    reg ready_out;

    reg [DATA_BYTE_WD-1:0] valid_values [0:DATA_BYTE_WD-1]; 
    reg [DATA_BYTE_WD-1:0] valid_values_2 [0:DATA_BYTE_WD-1];  
    reg all_1 [0:HEADER_NUM-1];

    axi_stream_insert_header #(
        .DATA_WD(DATA_WD),
        .DATA_BYTE_WD(DATA_BYTE_WD),
        .BYTE_CNT_WD(BYTE_CNT_WD)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .data_in(data_in),
        .keep_in(keep_in),
        .last_in(last_in),
        .ready_in(ready_in),

        .valid_out(valid_out),
        .data_out(data_out),
        .keep_out(keep_out),
        .last_out(last_out),
        .ready_out(ready_out),

        .valid_insert(valid_insert),
        .data_insert(data_insert),
        .keep_insert(keep_insert),
        .byte_insert_cnt('0),
        .ready_insert(ready_insert)
    );

    //original data发送模块
    axi_stream_master #(
        .DATA_WD(DATA_WD),
        .DATA_BYTE_WD(DATA_BYTE_WD),
        .BYTE_CNT_WD(BYTE_CNT_WD),
        .DATA_NUM(DATA_NUM),
        .NO_INTERRUPT(NO_INTERRUPT)
    ) master_data (
        .clk(clk),
        .rst_n(rst_n),
        .data_in_test(data_in_test),
        .keep_in_test(keep_in_test),
        .last_in_test(last_in_test),
        .delay_done(ramdom_delay),

        .valid_in(valid_in),
        .ready_in(ready_in),
        .data_in(data_in),
        .keep_in(keep_in),
        .last_in(last_in)
    );

    //original data发送模块
    axi_stream_master #(
        .DATA_WD(DATA_WD),
        .DATA_BYTE_WD(DATA_BYTE_WD),
        .BYTE_CNT_WD(BYTE_CNT_WD),
        .DATA_NUM(HEADER_NUM),
        .NO_INTERRUPT(NO_INTERRUPT)
    ) master_header (
        .clk(clk),
        .rst_n(rst_n),
        .data_in_test(data_header_test),
        .keep_in_test(keep_header_test),
        .last_in_test(all_1),
        .delay_done(ramdom_delay_2),

        .valid_in(valid_insert),
        .ready_in(ready_insert),
        .data_in(data_insert),
        .keep_in(keep_insert),
        .last_in()
    );

    always begin
        #5 clk = ~clk; 
    end
    always begin
        if ($urandom % 5 == 0) 
            ramdom_delay = 1;
        else
            ramdom_delay = 0;
        #10;
    end
    always begin
        if ($urandom % 5 == 0) 
            ramdom_delay_2 = 1;
        else
            ramdom_delay_2 = 0;
        #10;
    end
    always begin
        if ($urandom % 5 == 0) 
            ready_out = 1;
        else
            ready_out = 0;
        #10;
    end

    initial begin
        // seed_value = 12345;  
        // $urandom(seed_value);
        clk = 1;
        rst_n = 0;

        //data和header内容固定，方便测试
        foreach (data_in_test[i]) begin
            // data_in_test[i] = {DATA_WD{1'b1}};
            data_in_test[i] = $urandom; 
        end
        foreach (data_header_test[i]) begin
            // data_header_test[i] = {(DATA_WD/2){2'b01}};
            data_header_test[i] = $urandom; 
        end
        
        //输入数据流长度随机生成（平均长度为AVG_LENGTH可控）
        //每个数据流最后一个数据的使能部分随机生成
        for (int i = 0; i < DATA_BYTE_WD; i++) begin
            valid_values_2[i] = ((1 << i) - 1); 
        end
        foreach (last_in_test[i]) begin
            last_in_test[i] = 1'b0;
            keep_in_test[i] = {DATA_BYTE_WD{1'b1}};
        end
        last_in_test[DATA_NUM-1] = 1'b1;
        keep_in_test[DATA_NUM-1] = ~valid_values_2[$urandom % DATA_BYTE_WD];
        for (int i = 0; i < HEADER_NUM-1; i++) begin
            integer idx; 
            while (1) begin
                idx = $urandom_range(0, DATA_NUM-2);  
                if (last_in_test[idx] == 0) 
                    break;
            end
            last_in_test[idx] = 1;
            keep_in_test[idx] = ~valid_values_2[$urandom % DATA_BYTE_WD];
        end
        // last_in_test[1]=1'b1;
        // last_in_test[4]=1'b0;
        // keep_in_test[1]=4'b1110;
       
        //header长度随机生成
        for (int i = 0; i < DATA_BYTE_WD; i++) begin
            valid_values[i] = (1 << (i + 1)) - 1; 
        end
        foreach (keep_header_test[i]) begin
            keep_header_test[i] = valid_values[$urandom % DATA_BYTE_WD];  
        end
        // keep_header_test[0]= 4'b1111;

        for(int i = 0; i < HEADER_NUM; i++) begin
            all_1[i] = 1;
        end

        #20 rst_n = 1;

        #2000 $finish;
    end

endmodule
