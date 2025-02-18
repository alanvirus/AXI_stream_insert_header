//数据拼接模块，在axi_stream_insert_header.sv中使用
`timescale 1ns / 1ps
module data_combiner #(
    parameter DATA_WD = 32,
    parameter DATA_BYTE_WD = DATA_WD / 8,
    parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD)
) (
    input logic [DATA_WD-1:0]        data_1,
    input logic [DATA_BYTE_WD-1:0]  keep_1,
    input logic [DATA_WD-1:0]        data_2,
    input logic [DATA_BYTE_WD-1:0]  keep_2,
    output wire [DATA_WD-1:0]       combined_data_1,
    output wire [DATA_WD-1:0]       combined_data_2,
    output wire                     combine_overflow,
    output wire [DATA_BYTE_WD-1:0]  combined_keep_1,
    output wire [DATA_BYTE_WD-1:0]  combined_keep_2
);

    logic [BYTE_CNT_WD:0] cnt1, cnt2;

    always_comb begin
        cnt1 = 0;
        for (int i = DATA_BYTE_WD-1; i >= 0; i--) begin
            if (keep_1[i]) begin
                cnt1++;
            end
        end
    end

    always_comb begin
        cnt2 = 0;
        for (int i = DATA_BYTE_WD-1; i >= 0; i--) begin
            if (keep_2[i]) begin
                cnt2++;
            end
        end
    end

    logic [31:0] total_bytes;
    logic [31:0] total_bits;
    assign total_bytes = cnt1 + cnt2;
    assign total_bits = total_bytes * 8;
    // 溢出判断
    assign combine_overflow = (total_bytes > DATA_BYTE_WD);

    // 数据拼接
    localparam MAX_CONCAT_BITS = 2 * DATA_WD;
    logic [MAX_CONCAT_BITS-1:0] concat_data;
    logic [MAX_CONCAT_BITS-1:0] concat_data_left_aligned;
    always_comb begin
        concat_data = {data_1, data_2};
        concat_data_left_aligned = concat_data << (DATA_WD - cnt1*8);
    end
   
    //combined_data
    logic [DATA_WD-1:0] combined_data_1_wire, combined_data_2_wire;
    always_comb begin
        combined_data_1_wire  = concat_data_left_aligned[MAX_CONCAT_BITS-1:MAX_CONCAT_BITS-DATA_WD];
        combined_data_2_wire = concat_data_left_aligned[DATA_WD-1:0]>>(MAX_CONCAT_BITS-total_bits);
    end
    assign combined_data_1  = combined_data_1_wire;
    assign combined_data_2   = combined_data_2_wire;

    //keep
    logic [DATA_BYTE_WD-1:0] combined_keep_1_wire,combined_keep_2_wire;
    always_comb begin
        combined_keep_1_wire = '0;
        for (int i = 0; i < DATA_BYTE_WD; i++) begin
            combined_keep_1_wire[DATA_BYTE_WD-1-i] = (i < total_bytes);
        end
    end
    always_comb begin
        combined_keep_2_wire = '0;
        if(combine_overflow) begin    
            for (int j = 0; j < DATA_BYTE_WD; j++) begin
                combined_keep_2_wire[j] = (j<(total_bytes-DATA_BYTE_WD));
            end
        end
    end
    assign combined_keep_1  = combined_keep_1_wire;
    assign combined_keep_2  = combined_keep_2_wire;

endmodule