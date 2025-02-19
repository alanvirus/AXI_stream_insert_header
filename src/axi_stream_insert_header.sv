//主模块，用于将header插入到AXI Stream数据流开头
`timescale 1ns / 1ps
module axi_stream_insert_header #(
    parameter DATA_WD = 32,
    parameter DATA_BYTE_WD = DATA_WD / 8,
    parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD)
) (
    input clk,
    input rst_n,
    // AXI Stream input original data
    input valid_in,
    input [DATA_WD-1 : 0] data_in,
    input [DATA_BYTE_WD-1 : 0] keep_in,
    input last_in,
    output ready_in,

    // AXI Stream output with header inserted
    output valid_out,
    output [DATA_WD-1 : 0] data_out,
    output [DATA_BYTE_WD-1 : 0] keep_out,
    output last_out,
    input ready_out,

    // The header to be inserted to AXI Stream input
    input valid_insert,
    input [DATA_WD-1 : 0] data_insert,
    input [DATA_BYTE_WD-1 : 0] keep_insert,
    input [BYTE_CNT_WD-1 : 0] byte_insert_cnt,
    output ready_insert
);
    reg ready_in_reg;

    //输出端skidbuffer
    reg valid_out_buf_reg;
    reg [DATA_WD-1 : 0] data_out_buf_reg;
    reg [DATA_BYTE_WD-1 : 0] keep_out_buf_reg;
    reg last_out_buf_reg;
    wire ready_out_buf_wire;
    skidbuffer #(
		.DW(DATA_WD+DATA_BYTE_WD+1)
	) out_buf(
		.i_clk(clk), .i_reset(rst_n),
		.i_valid(valid_out_buf_reg), 
        .o_ready(ready_out_buf_wire),
		.i_data({data_out_buf_reg, keep_out_buf_reg, last_out_buf_reg}),
		.o_valid(valid_out), 
        .i_ready(ready_out),
		.o_data({data_out, keep_out, last_out})
	);

    //header端skidbuffer
    wire valid_header_buf_wire;
    wire [DATA_WD-1 : 0] data_header_buf_wire;
    wire [DATA_BYTE_WD-1 : 0] keep_header_buf_wire;
    wire [BYTE_CNT_WD-1 : 0] byte_cnt_header_buf_wire;
    reg ready_header_buf_reg;
    skidbuffer #(
		.DW(DATA_WD+DATA_BYTE_WD+BYTE_CNT_WD)
    ) header_buf(
		.i_clk(clk), .i_reset(rst_n),
		.i_valid(valid_insert), 
        .o_ready(ready_insert),
		.i_data({data_insert, keep_insert, byte_insert_cnt}),
		.o_valid(valid_header_buf_wire), 
        .i_ready(ready_header_buf_reg&&rst_n),
		.o_data({data_header_buf_wire, keep_header_buf_wire, byte_cnt_header_buf_wire})
	);

    //接收数据流过程中置0，防止header被错误插入
    reg need_head_reg;
    //当header与data合并时，多余出来的部分可视作下一个数据的header，与header一样右侧部分有效
    reg [DATA_WD-1 : 0] next_head_buf_reg;
    reg [DATA_BYTE_WD-1 : 0] next_keep_buf_reg;
    //用于拼接的两个数据
    logic [DATA_WD-1:0] data_to_be_combined_1_wire;
    logic [DATA_BYTE_WD-1:0] keep_to_be_combined_1_wire;
    logic [DATA_WD-1:0] data_to_be_combined_2_wire;
    logic [DATA_BYTE_WD-1:0] keep_to_be_combined_2_wire;
    always_comb begin
        if((!valid_out_buf_reg&&need_head_reg)||(valid_out_buf_reg&&need_head_reg&&last_out_buf_reg))begin
            {data_to_be_combined_1_wire, keep_to_be_combined_1_wire} = {data_header_buf_wire, keep_header_buf_wire};
        end else begin
            {data_to_be_combined_1_wire, keep_to_be_combined_1_wire} = {next_head_buf_reg, next_keep_buf_reg};
        end
    end
    always_comb begin
        if(valid_out_buf_reg&&need_head_reg&&!last_out_buf_reg)begin
            {data_to_be_combined_2_wire, keep_to_be_combined_2_wire} = '0;
        end else begin
            {data_to_be_combined_2_wire, keep_to_be_combined_2_wire} = {data_in, keep_in};
        end
    end
    //拼接后的数据，1左侧贴靠，2右侧贴靠
    wire [DATA_WD-1:0] combined_data_1_wire;
    wire [DATA_WD-1:0] combined_data_2_wire;
    wire combine_overflow_wire;
    wire [DATA_BYTE_WD-1 : 0] combined_keep_1_wire;
    wire [DATA_BYTE_WD-1 : 0] combined_keep_2_wire;
    data_combiner #(
        .DATA_WD(DATA_WD),
        .DATA_BYTE_WD(DATA_BYTE_WD),
        .BYTE_CNT_WD(BYTE_CNT_WD)
    ) combiner(
        .data_1(data_to_be_combined_1_wire),
        .keep_1(keep_to_be_combined_1_wire),
        .data_2(data_to_be_combined_2_wire),
        .keep_2(keep_to_be_combined_2_wire),
        .combined_data_1(combined_data_1_wire),
        .combined_data_2(combined_data_2_wire),
        .combine_overflow(combine_overflow_wire),
        .combined_keep_1(combined_keep_1_wire),
        .combined_keep_2(combined_keep_2_wire)
    );
    //valid_out_buf_reg,need_head_reg
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            valid_out_buf_reg <= 1'b0;
            need_head_reg <= 1'b1;
        end else begin
            if(ready_in&&valid_in)begin
                need_head_reg <= last_in;
                valid_out_buf_reg <= 1'b1;
            end else begin
                valid_out_buf_reg <= valid_out_buf_reg&&(!ready_out_buf_wire ||(need_head_reg && !last_out_buf_reg));
            end
        end
    end
    //last_out_buf_reg,data_out_buf_reg, keep_out_buf_reg, next_head_buf_reg, next_keep_buf_reg
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            last_out_buf_reg <= 1'b0;
            data_out_buf_reg <='0;
            keep_out_buf_reg <='0;
            next_head_buf_reg <= '0;
            next_keep_buf_reg <= '0;
        end else begin
            if(valid_out_buf_reg&&!ready_out_buf_wire)begin
            end else if(!valid_out_buf_reg&&!need_head_reg&&!valid_in)begin
            end else begin
                last_out_buf_reg <= !combine_overflow_wire;
                data_out_buf_reg <= combined_data_1_wire;
                keep_out_buf_reg <= combined_keep_1_wire;
                next_head_buf_reg <= combined_data_2_wire;
                next_keep_buf_reg <= combined_keep_2_wire;
            end
        end
    end
    //ready_in_reg and ready_header_buf_reg
    always_comb begin
        if(valid_out_buf_reg)begin
            if(need_head_reg)begin
                if(last_out_buf_reg)begin
                    ready_in_reg = ready_out_buf_wire&&valid_header_buf_wire;
                    ready_header_buf_reg = ready_out_buf_wire&&valid_in;
                end else begin
                    ready_in_reg = 0;
                    ready_header_buf_reg = 0;
                end
            end else begin
                ready_in_reg = ready_out_buf_wire;
                ready_header_buf_reg = 0;
            end
        end else begin
            if(need_head_reg)begin
                ready_in_reg = valid_header_buf_wire;
                ready_header_buf_reg = valid_in;
            end else begin
                ready_in_reg = 1;
                ready_header_buf_reg = 0;
            end
        end
    end
    assign ready_in = ready_in_reg&&rst_n;
endmodule