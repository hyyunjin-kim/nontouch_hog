`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/07/23 09:58:33
// Design Name: 
// Module Name: ControlUnit_UART
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


module ControlUnit_UART(
    input logic clk,
    input logic reset,

    input logic tx_state_stop,
    // input logic HOG_DONE,

    input logic [8:0] point_x,
    input logic [7:0] point_y,
    input logic  gesture,


    output logic start_trigger,
    output logic [7:0] UART_TX_DATA
    );


    typedef enum {IDLE, SEND_X, SEND_Y , SEND_GESTURE} state_e;

    state_e current_state, next_state;
    logic [8:0] temp_x, next_x;
    logic [7:0] temp_y, next_y;
    logic  temp_gesture, next_gesture;
    logic tick_100ms;
    logic tx_stop_next; 
    logic edge_tx_stop;

    assign edge_tx_stop = ~tx_state_stop & tx_stop_next;

 
        baud_tick_gen #(
        .BAUD_RATE(100)
        ) u_tick_10ms (
        .clk(clk),
        .reset(reset),

        .baud_tick(tick_100ms)
    );

    always_ff@(posedge clk , posedge reset) begin
        if(reset) begin
            current_state <= IDLE;
            // start_trigger <= 0;
            temp_x <= 0;
            temp_y <= 0;
            temp_gesture <= 0;
        end
        else begin
            current_state <= next_state; 
            temp_x <= next_x;
            temp_y <= next_y;
            temp_gesture <= next_gesture;
            tx_stop_next <= tx_state_stop;
        end
    end

    always_comb begin
        next_state = current_state;  
        start_trigger = 0;
        UART_TX_DATA = 0;
        next_x = temp_x;
        next_y = temp_y;
        next_gesture = temp_gesture;

        case(current_state)
        IDLE: begin         
            if(tick_100ms) begin
                 next_state = SEND_X;
                 next_x = point_x;
                next_y = point_y;
                next_gesture = gesture;
                 start_trigger = 1'b1;
           end 
        end
        SEND_X :begin

            UART_TX_DATA = temp_x[8:1];
            if(edge_tx_stop) begin 
                next_state = SEND_Y;
                start_trigger = 1'b1;
            end
        end
        SEND_Y: begin
           
           UART_TX_DATA = temp_y; 
           if(edge_tx_stop)begin
            next_state = SEND_GESTURE;
            start_trigger = 1'b1;
           end
        end
        SEND_GESTURE: begin
           
           UART_TX_DATA = {temp_x[0],temp_gesture,{6{1'b0}}};
           if(edge_tx_stop) begin
            next_state = IDLE;
            start_trigger = 1'b1;
           end
        end
        endcase 
    end
endmodule
