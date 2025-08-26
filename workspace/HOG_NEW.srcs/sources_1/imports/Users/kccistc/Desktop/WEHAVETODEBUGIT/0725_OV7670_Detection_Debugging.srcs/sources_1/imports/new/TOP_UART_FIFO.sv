`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/07/23 09:52:04
// Design Name: 
// Module Name: TOP_UART_FIFO
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

module fifo_uart(
    input clk,
    input reset,
    input uart_rx_in,
    input [2:0] sw_mode,

    input measure_done,

    input [7:0] tx_data,
    input start_trigger,
    
    
    // output rd,
    output uart_tx_out,
    output [7:0] fifo_rx_data,

    output tx_stop

);

wire [7:0] rx_rdata,  tx_rdata;
wire tx_full;
wire tx_empty, rx_empty;

wire rx_done,tx_done;
wire w_tx_rd;

//uart

wire tx_out;
wire [7:0] rx_data;


// distance화면 => 9비트라 일단 안씀
fifo fifo_tx (
    .clk(clk),
    .reset(reset),
    //write

    .wdata(tx_data),
    .wr(measure_done | start_trigger),

    .full(tx_full),
    //read
    .rd(~tx_empty),

    .rdata(tx_rdata),
    .empty(tx_empty)

);

fifo fifo_rx (
    .clk(clk),
    .reset(reset),
    //write
    .wdata(rx_data),
    .wr(rx_done),

    .full(),

    //read
    .rd(~tx_full&~rx_empty),

    .rdata(fifo_rx_data),
    .empty(rx_empty)

);

uart #(
    .BAUD_RATE(115200*16),
    .DATA_SIZE(8)
) u_uart (
    .clk(clk),
    .reset(reset),

    //tx
    .btn_start_trigger(~tx_empty & (start_trigger | measure_done)),
    // .tx_in(row_tx_data),
     .tx_in(tx_rdata),
     .tx_rd(~tx_empty),

    .tx_out(uart_tx_out),
    .tx_done(tx_done),
    .tx_stop(tx_stop),

    //rx
    .rx_data(uart_rx_in),

    .rx_out(rx_data),
    .rx_done(rx_done)
);


endmodule
