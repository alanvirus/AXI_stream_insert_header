//数据拼接模块，在axi_stream_insert_header.sv中使用
`timescale 1ns / 1ps
module data_combiner #(
    parameter DATA_WD = 32,
    parameter DATA_BYTE_WD = DATA_WD / 8,
    parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD)
) (
    input wire [DATA_WD-1:0]        data_1,
    input wire [DATA_BYTE_WD-1:0]  keep_1,
    input wire [DATA_WD-1:0]        data_2,
    input wire [DATA_BYTE_WD-1:0]  keep_2,
    output reg [DATA_WD-1:0]       combined_data_1_wire,
    output reg [DATA_WD-1:0]       combined_data_2_wire,
    output wire                     combine_overflow,
    output reg [DATA_BYTE_WD-1:0]  combined_keep_1_wire,
    output reg [DATA_BYTE_WD-1:0]  combined_keep_2_wire
);

    reg [BYTE_CNT_WD:0] cnt1_wire, cnt2_wire;
    always_comb begin
        cnt1_wire = 0;
        for (int i = DATA_BYTE_WD-1; i >= 0; i--) begin
            if (keep_1[i]) begin
                cnt1_wire++;
            end
        end
    end
    always_comb begin
        cnt2_wire = 0;
        for (int i = DATA_BYTE_WD-1; i >= 0; i--) begin
            if (keep_2[i]) begin
                cnt2_wire++;
            end
        end
    end
    wire [31:0] total_bytes_wire;
    wire [31:0] total_bits_wire;
    assign total_bytes_wire = cnt1_wire + cnt2_wire;
    assign total_bits_wire = total_bytes_wire * 8;
    // 溢出判断
    assign combine_overflow = (total_bytes_wire > DATA_BYTE_WD);

    // 数据拼接
    localparam MAX_CONCAT_BITS = 2 * DATA_WD;
    reg [MAX_CONCAT_BITS-1:0] concat_data_wire;
    reg [MAX_CONCAT_BITS-1:0] concat_data_left_aligned_wire;
    always_comb begin
        concat_data_wire = {data_1, data_2};
        concat_data_left_aligned_wire = concat_data_wire << (DATA_WD - cnt1_wire*8);
    end
   
    //combined_data
    always_comb begin
        combined_data_1_wire  = concat_data_left_aligned_wire[MAX_CONCAT_BITS-1:MAX_CONCAT_BITS-DATA_WD];
        combined_data_2_wire = concat_data_left_aligned_wire[DATA_WD-1:0]>>(MAX_CONCAT_BITS-total_bits_wire);
    end
   
    //keep
    always_comb begin
        combined_keep_1_wire = '0;
        for (int i = 0; i < DATA_BYTE_WD; i++) begin
            combined_keep_1_wire[DATA_BYTE_WD-1-i] = (i < total_bytes_wire);
        end
    end
    always_comb begin
        combined_keep_2_wire = '0;
        if(combine_overflow) begin    
            for (int j = 0; j < DATA_BYTE_WD; j++) begin
                combined_keep_2_wire[j] = (j<(total_bytes_wire-DATA_BYTE_WD));
            end
        end
    end

endmodule