//测试数据发送模块
module axi_stream_master #(
    parameter DATA_WD = 32,
    parameter DATA_BYTE_WD = DATA_WD / 8,
    parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD),
    parameter DATA_NUM =12,
    parameter NO_INTERRUPT = 0
) (
    input wire clk,                  
    input wire rst_n,                 
    input wire [DATA_WD-1:0] data_in_test [0:DATA_NUM-1], 
    input wire [DATA_BYTE_WD-1:0] keep_in_test [0:DATA_NUM-1],
    input wire last_in_test [0:DATA_NUM-1],

    input wire delay_done,

    output reg valid_in,                
    input wire ready_in,                
    output reg [DATA_WD-1:0] data_in,  
    output reg [DATA_BYTE_WD-1:0] keep_in, 
    output reg last_in                 
);
    typedef enum reg [1:0] {
        IDLE = 2'b00,
        SEND = 2'b01,
        STOP = 2'b10
    } state_t;

    state_t state, next_state;
    reg [31:0] counter;  

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE; 
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        case (state)
            IDLE: begin
                if (delay_done) begin
                    next_state = SEND; 
                end else begin
                    next_state = IDLE; 
                end
            end

            SEND: begin
                if (ready_in && last_in_test[counter]) begin
                    if(counter == DATA_NUM - 1) begin
                        next_state = STOP; 
                    end else if(delay_done || NO_INTERRUPT) begin
                        next_state =SEND;
                    end else begin
                        next_state = IDLE; 
                    end 
                end else if(ready_in)begin
                    if(delay_done)begin
                        next_state =SEND;
                    end else begin
                        next_state = IDLE; 
                    end
                end else begin
                    next_state = SEND; 
                end
            end
            STOP: begin
                next_state = STOP; 
            end

            default: next_state = IDLE; 
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            valid_in <= 0;
            data_in <= '0;
            keep_in <= '0;
            last_in <= 0;
            counter <= '0;
        end else begin
            case (state)
                IDLE: begin
                    if (delay_done) begin
                        valid_in <= 1;
                        data_in <= data_in_test[counter];
                        keep_in <= keep_in_test[counter];
                        last_in <= last_in_test[counter];
                    end else begin
                        
                    end
                end

                SEND: begin
                    if (ready_in && last_in_test[counter]) begin
                        if(counter == DATA_NUM - 1) begin
                            valid_in <= 0;
                        end else if(delay_done || NO_INTERRUPT) begin
                            valid_in <= 1;
                            data_in <= data_in_test[counter+1];
                            keep_in <= keep_in_test[counter+1];
                            last_in <= last_in_test[counter+1];
                            counter <= counter + 1;
                        end else begin
                            valid_in <= 0;
                            counter <= counter + 1;
                        end 
                    end else if(ready_in)begin
                        if(!delay_done)begin
                            valid_in <= 0;
                            counter <= counter + 1;
                        end else begin     
                            valid_in <= 1;
                            data_in <= data_in_test[counter+1];
                            keep_in <= keep_in_test[counter+1];
                            last_in <= last_in_test[counter+1];
                            counter <= counter + 1;
                        end
                    end else begin
                    end
                end
                STOP : begin
                    valid_in <= 0;
                    counter <= '0;
                end
                default: begin
                    valid_in <= 0;
                    counter <= '0;
                end
            endcase
        end
    end
endmodule
