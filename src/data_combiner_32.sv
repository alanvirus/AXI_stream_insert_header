//数据拼接模块，在axi_stream_insert_header.sv中使用
`timescale 1ns / 1ps
module data_combiner_32 #(
    parameter DATA_WD = 32,
    parameter DATA_BYTE_WD = DATA_WD / 8,
    parameter BYTE_CNT_WD = 2
) (
    input wire [31:0]        data_1,
    input wire [3:0]  keep_1,
    input wire [31:0]        data_2,
    input wire [3:0]  keep_2,
    output wire [31:0]       combined_data_1_wire,
    output wire [31:0]       combined_data_2_wire,
    output wire                     combine_overflow,
    output reg [3:0]  combined_keep_1_wire,
    output reg [3:0]  combined_keep_2_wire
);
    int cnt1_wire, cnt2_wire;
    always_comb begin
        cnt1_wire = 0;
        foreach(keep_1[i])begin
            cnt1_wire+=keep_1[i];
        end
        // for (int i = 3; i >= 0; i--) begin
        //     if (keep_1[i]) begin
        //         cnt1_wire++;
        //     end
        // end
    end
    always_comb begin
        cnt2_wire = 0;
        foreach(keep_2[i])begin
            cnt2_wire+=keep_2[i];
        end
        // for (int i = 3; i >= 0; i--) begin
        //     if (keep_2[i]) begin
        //         cnt2_wire++;
        //     end
        // end
    end
    int total_bytes_wire;
    int total_bits_wire;
    assign total_bytes_wire = cnt1_wire + cnt2_wire;
    assign total_bits_wire = total_bytes_wire<<3;
    // 溢出判断
    assign combine_overflow = (total_bytes_wire>4);
    // 数据拼接
    wire [63:0] concat_data_left_aligned_wire;
    wire [63:0] concat_data_right_aligned_wire;
    assign concat_data_left_aligned_wire = {data_1, data_2} << (32 - cnt1_wire*8);
    assign concat_data_right_aligned_wire = {data_1, data_2} >> (32 - cnt2_wire*8);
    //data
    assign combined_data_1_wire  = concat_data_left_aligned_wire[63:32];
    assign combined_data_2_wire = concat_data_right_aligned_wire[31:0];
    //keep
    always_comb begin
        // combined_keep_1_wire = '0;
        for (int i = 0; i < 4; i++) begin
            combined_keep_1_wire[3-i] = (i < total_bytes_wire);
        end
    end
    always_comb begin
        for (int j = 4; j < 8; j++) begin
            combined_keep_2_wire[j-4] = (j < total_bytes_wire);
        end
    end
endmodule