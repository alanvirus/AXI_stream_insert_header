//主模块，用于将header插入到AXI Stream数据流开头
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
    //data输入端未使用skidbuffer,可以添加
    logic ready_in_wire;

    //输出端skidbuffer
    reg valid_out_buf;
    reg [DATA_WD-1 : 0] data_out_buf;
    reg [DATA_BYTE_WD-1 : 0] keep_out_buf;
    reg last_out_buf;
    wire ready_out_buf;
    skidbuffer #(
		.DW(DATA_WD+DATA_BYTE_WD+1)
	) out_buf(
		.i_clk(clk), .i_reset(rst_n),
		.i_valid(valid_out_buf), 
        .o_ready(ready_out_buf),
		.i_data({data_out_buf, keep_out_buf, last_out_buf}),
		.o_valid(valid_out), 
        .i_ready(ready_out),
		.o_data({data_out, keep_out, last_out})
	);

    //header端skidbuffer
    wire valid_header_buf;
    wire [DATA_WD-1 : 0] data_header_buf;
    wire [DATA_BYTE_WD-1 : 0] keep_header_buf;
    wire [BYTE_CNT_WD-1 : 0] byte_cnt_header_buf;
    logic ready_header_buf;
    skidbuffer #(
		.DW(DATA_WD+DATA_BYTE_WD+BYTE_CNT_WD)
    ) header_buf(
		.i_clk(clk), .i_reset(rst_n),
		.i_valid(valid_insert), 
        .o_ready(ready_insert),
		.i_data({data_insert, keep_insert, byte_insert_cnt}),
		.o_valid(valid_header_buf), 
        .i_ready(ready_header_buf&&rst_n),
		.o_data({data_header_buf, keep_header_buf, byte_cnt_header_buf})
	);

    
    //接收数据流过程中置0，防止header被错误插入
    reg need_head;

    //当header与data合并时，多余出来的部分可视作下一个数据的header，与header一样右侧部分有效
    reg [DATA_WD-1 : 0] next_head_buf;
    reg [DATA_BYTE_WD-1 : 0] next_keep_buf;

    //用于拼接的两个数据
    logic [DATA_WD-1:0] data_to_be_combined_1;
    logic [DATA_BYTE_WD-1:0] keep_to_be_combined_1;
    logic [DATA_WD-1:0] data_to_be_combined_2;
    logic [DATA_BYTE_WD-1:0] keep_to_be_combined_2;
    always_comb begin
        if((!valid_out_buf&&need_head)||(valid_out_buf&&need_head&&last_out_buf))begin
            data_to_be_combined_1 = data_header_buf;
            keep_to_be_combined_1 = keep_header_buf;
        end else begin
            data_to_be_combined_1 = next_head_buf;
            keep_to_be_combined_1 = next_keep_buf;
        end
    end
    always_comb begin
        if(valid_out_buf&&need_head&&!last_out_buf)begin
            data_to_be_combined_2 = '0;
            keep_to_be_combined_2 = '0;
        end else begin
            data_to_be_combined_2 = data_in;
            keep_to_be_combined_2 = keep_in;
        end
    end

    //拼接后的数据，1左侧贴靠，2右侧贴靠
    wire [DATA_WD-1:0] combined_data_1;
    wire [DATA_WD-1:0] combined_data_2;
    wire combine_overflow;
    wire [DATA_BYTE_WD-1 : 0] combined_keep_1;
    wire [DATA_BYTE_WD-1 : 0] combined_keep_2;

    data_combiner #(
        .DATA_WD(DATA_WD),
        .DATA_BYTE_WD(DATA_BYTE_WD),
        .BYTE_CNT_WD(BYTE_CNT_WD)
    ) combiner(
        .data_1(data_to_be_combined_1),
        .keep_1(keep_to_be_combined_1),
        .data_2(data_to_be_combined_2),
        .keep_2(keep_to_be_combined_2),
        .combined_data_1(combined_data_1),
        .combined_data_2(combined_data_2),
        .combine_overflow(combine_overflow),
        .combined_keep_1(combined_keep_1),
        .combined_keep_2(combined_keep_2)
    );

    //valid_out_buf
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            valid_out_buf <= 1'b0;
        end else begin
            if(ready_in&&valid_in)begin  
                valid_out_buf <= 1'b1;
            end else if(valid_out_buf)begin 
                valid_out_buf <= !ready_out_buf ||(need_head && !last_out_buf);
            end
        end
    end
    //need_head
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            need_head <= 1'b1;
        end else begin
            if(ready_in&&valid_in)begin
                need_head <= last_in;
            end 
        end
    end
    //last_out_buf
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            last_out_buf <= 1'b0;
        end else begin
            if(valid_out_buf&&!ready_out_buf)begin
            end else begin
                last_out_buf <= !combine_overflow;
            end
        end
    end
    //data_out_buf,keep_out_buf
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            data_out_buf <='0;
            keep_out_buf <='0;
        end else begin
            if(valid_out_buf&&!ready_out_buf)begin
            end else begin
                data_out_buf <= combined_data_1;
                keep_out_buf <= combined_keep_1;
            end
        end
    end
    //next_head_buf,next_keep_buf
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            next_head_buf <= '0;
            next_keep_buf <= '0;
        end else begin
            if(valid_out_buf&&!ready_out_buf)begin
            end else if(!valid_out_buf&&!need_head&&!valid_in)begin
            end else begin
                next_head_buf <= combined_data_2;
                next_keep_buf <= combined_keep_2;
            end
        end
    end

    //ready_in
    always_comb begin
        if(valid_out_buf)begin
            if(need_head)begin
                if(last_out_buf)begin
                    ready_in_wire = ready_out_buf&&valid_header_buf;
                end else begin
                    ready_in_wire = 0;
                end
            end else begin
                ready_in_wire = ready_out_buf;
            end
        end else begin
            if(need_head)begin
                ready_in_wire = valid_header_buf;
            end else begin
                ready_in_wire = 1;
            end
        end
    end
    assign ready_in = ready_in_wire&&rst_n;

    //ready_header_buf
    always_comb begin
        if(!need_head || (valid_header_buf&&!last_out_buf))begin
            ready_header_buf = 0;
        end else begin
            ready_header_buf = valid_in&&ready_in;
        end
    end


endmodule