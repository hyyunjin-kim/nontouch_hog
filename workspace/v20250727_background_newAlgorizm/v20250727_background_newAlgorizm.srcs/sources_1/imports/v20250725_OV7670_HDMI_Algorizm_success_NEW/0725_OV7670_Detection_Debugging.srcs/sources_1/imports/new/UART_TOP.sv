`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/07/23 09:49:16
// Design Name: 
// Module Name: UART_TOP
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module uart #(
    parameter BAUD_RATE = 9600,
    parameter DATA_SIZE = 8
) (
    input clk,
    input reset,

    //tx
    input btn_start_trigger,
    input [7:0] tx_in,
    input tx_rd,

    output tx_out,
    output tx_done,
    output tx_stop,

    //rx
    input rx_data,

    output [7:0] rx_out,
    output rx_done
);

    wire w_tick;
    wire is_start;



    baud_tick_gen #(
        .BAUD_RATE(BAUD_RATE)
    ) u_baud (
        .clk(clk),
        .reset(reset),

        .baud_tick(w_tick)
    );

    uart_tx #(
        .DATA_SIZE(DATA_SIZE)
    ) u_uart_tx (
        .clk(clk),
        .reset(reset),
        .tick(w_tick),
        .start_trigger(btn_start_trigger),
        .D(tx_in),  // data_in
        .tx_rd(tx_rd),

        .o_tx(tx_out),
        .o_tx_done(tx_done),
        .tx_stop(tx_stop)
        
    );

    uart_rx #(
    .DATA_SIZE(DATA_SIZE)
)    u_uart_rx (
        .clk(clk),
        .reset(reset),
        .rx_in(rx_data),
        .tick(w_tick),


        .rx_out(rx_out),
        .rx_done(rx_done)
       
);

endmodule

// btn start 알아서 진행 

module uart_tx #(
    parameter DATA_SIZE = 8,
    parameter BIT_SIZE = $clog2(DATA_SIZE),
    parameter UPCONVERT_RATE = 16
) (  // tick_count => data_bit 크기 
    input clk,
    input reset,
    input tick,
    input start_trigger,
    // input [DATA_SIZE - 1:0] D,  // data_in // 한번만
    input [DATA_SIZE -1:0] D,
    input tx_rd,

    output o_tx,
    output o_tx_done,
    output tx_stop

);

    localparam IDLE = 3'b000, SEND = 3'b001, START = 3'b010, DATA = 3'b011, STOP = 3'b100;


    reg [2:0] current_state, next_state;
    reg tx_current, tx_next;
    reg c_tx_done, n_tx_done;
    reg [BIT_SIZE - 1:0] c_bit_count, n_bit_count;
    reg [$clog2(UPCONVERT_RATE)-1:0] c_tick_count, n_tick_count;
    // tx_data in buffer 
    reg[7:0] temp_data_reg, temp_data_next;


    assign tx_stop = (current_state == STOP) ? 1'b1 : 1'b0;
    assign o_tx_done = c_tx_done;
    assign o_tx = tx_current;
  

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
            tx_current <= 1'b0;
            c_tx_done <= 1'b0;
            c_tick_count <= 0;
            c_bit_count <= 0;
            temp_data_reg <= 0;

        end else begin
            current_state <= next_state;
            tx_current <= tx_next;
            c_tx_done <= n_tx_done;
            c_tick_count <= n_tick_count;
            c_bit_count <= n_bit_count;
            temp_data_reg <= temp_data_next;
    
        end
    end

    always @(*) begin
        tx_next = tx_current;  // if문 아닐때 현재값 유지 
        next_state = current_state;
        n_tx_done = c_tx_done;
        n_tick_count = c_tick_count;
        n_bit_count = c_bit_count;
        temp_data_next = temp_data_reg;

       
        case (current_state)  // 현재 상태를 기준으로 
            IDLE: begin

                tx_next = 1'b1;
                if (tx_rd) begin
                    next_state = SEND;
                    n_tick_count = 0;
                    n_tx_done  = 1'b1;
                    // start trigger 순간 data를 buffering 하기 위함 
                    temp_data_next = D;

                end

            end

            SEND: begin
                if(tick) begin
                    n_tick_count = 0;
                    next_state = START;
                end
            end

            START: begin
                tx_next = 1'b0;
                
                if(tick) begin
                    if (c_tick_count == 15) begin
                        n_tick_count = 0;
                        next_state = DATA;
                        n_bit_count = 0;
                       

                    end
                    else begin
                        n_tick_count = c_tick_count + 1;
                    end
                end

            end

            DATA: begin
                
                tx_next = temp_data_reg[c_bit_count];
                if(tick) begin
                    if(c_tick_count == 15) begin
                        n_tick_count = 0;
                        if (c_bit_count == 7) begin
                            next_state = STOP;
                            n_tx_done  = 1'b1;
                            n_bit_count = 0;
                        end
                    
                        else begin
                            n_bit_count = c_bit_count + 1;
                        end
                    end
                    else begin
                        n_tick_count = c_tick_count + 1;
                    end
                end
            end
                //유지시키기

                //같은 output을 내는 if문에서는 else if 


            STOP: begin
                tx_next   = 1'b1;
                n_tx_done = 1'b0;
                if(tick) begin
                    if (c_tick_count == 15) begin

                        next_state = IDLE;
                        n_tick_count = 0;

                    end
                    else begin
                        n_tick_count = c_tick_count + 1;
                    end
                end
            end
        endcase
    end

endmodule

module uart_rx #(
    parameter DATA_SIZE = 8,
    parameter BIT_SIZE = $clog2(DATA_SIZE),
    parameter UPCONVERT_RATE = 16
) (
    input clk,
    input reset,
    input rx_in,
    input tick,


    output [DATA_SIZE-1:0] rx_out,
    output rx_done
    
);
// if 에는 current ,조합 output에는 next
   localparam IDLE = 3'b000, SEND = 3'b001, START = 3'b010, DATA = 3'b011, STOP = 3'b100;

    reg[2:0] current_state, next_state;
    reg c_done, n_done;
    reg [BIT_SIZE-1 : 0] c_bit_count, n_bit_count;
    reg [$clog2(23)-1 : 0] c_tick_count, n_tick_count;
    reg c_rx_done, n_rx_done;
    reg [DATA_SIZE -1 :0] c_rx_out, n_rx_out; 
    reg n_r_in;

    // wire is_start;
    // assign is_start = (rx_in == 1'b0  && n_r_in == 1'b1) ? 1'b1 : 1'b0; 

    //case 문 내부로 한방에 ㄱㄱ 

    assign rx_out = c_rx_out;
    assign rx_done = c_rx_done;
    
    always @(posedge clk, posedge reset) begin
        if(reset) begin
            current_state <= IDLE;
            c_done <= 1'b0;
            c_bit_count <= 0;
            c_tick_count <= 0;
            c_rx_done <= 0;
            c_rx_out <= 0;
        
        end

        else begin
            current_state <= next_state;
            c_done <= n_done;
            c_bit_count <= n_bit_count;
            c_tick_count <= n_tick_count;
            c_rx_done <= n_rx_done;
            c_rx_out <= n_rx_out;
            n_r_in <= rx_in;
        end
        
    end

    always @(*) begin
        next_state = current_state;
        n_bit_count = c_bit_count;
        n_tick_count = c_tick_count;
        n_done =c_done;
        n_rx_done = c_rx_done;
        n_rx_out = c_rx_out;
        // if문 밖에서 latch 말고 F/F으로 만들어줌 
        case (current_state)
            IDLE: begin
                n_tick_count = 0;
                n_bit_count = 0;
                n_done = 1'b0;
                n_rx_done = 1'b0;
                
                
                if(rx_in == 1'b0) begin
                    next_state = SEND;
                end
            end 

              SEND: begin
                if(tick) begin
                    n_tick_count = 0;
                    next_state = START;
                end
            end

            START: begin
                if(tick) begin
                    if(c_tick_count == 7) begin
                        next_state = DATA;
                        n_tick_count = 0;
                    end

                    else begin
                        n_tick_count = c_tick_count + 1;
                    end
                 end
            end

            DATA: begin
                  n_rx_out[c_bit_count] = rx_in; 
                if(tick) begin
                    // mealy로 내보내야지 
                    if(c_tick_count == 15) begin // output은 mealy 모델로 하는게 맛있음 
                        n_tick_count = 0;
                       
                       
                        if(c_bit_count == 7) begin
                            next_state = STOP;
                            n_bit_count = 0;
                            n_tick_count = 0;
                        end
                        else begin
                            n_bit_count = c_bit_count + 1;
                        end
                        
                    end
                    else begin
                        n_tick_count = c_tick_count + 1;

                    end
                end
            end

            STOP: begin
                if(tick) begin 
                    if(c_tick_count == 23) begin
                        n_rx_done = 1'b1;
                        n_tick_count = 0;
                        next_state = IDLE;
                    end

                    else begin
                        n_tick_count = c_tick_count + 1;
                    end
            end
            end
            
        endcase
    end

endmodule

module baud_tick_gen #(
    parameter BAUD_RATE = 9600
) (
    input clk,
    input reset,

    output baud_tick

);
    localparam BAUD_COUNT = 125_000_000 / BAUD_RATE;
    reg [$clog2(BAUD_COUNT)-1:0] count_current, count_next;
    reg tick_current, tick_next;

    assign baud_tick = tick_current;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            count_current <= 0;
            tick_current  <= 1'b0;
        end else begin
            count_current <= count_next;
            tick_current  <= tick_next;
        end
    end

    always @(*) begin
        count_next = 0;
        tick_next  = 1'b0;
        
            if (count_current == BAUD_COUNT - 1) begin
                count_next = 0;
                tick_next  = 1'b1;
            end else begin
                count_next = count_current + 1;
                tick_next  = 1'b0;
            end
    

    end


endmodule

