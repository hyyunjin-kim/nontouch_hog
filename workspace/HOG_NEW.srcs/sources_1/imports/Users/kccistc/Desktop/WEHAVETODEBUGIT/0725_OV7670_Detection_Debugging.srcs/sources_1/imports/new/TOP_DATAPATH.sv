`timescale 1ns / 1ps


module TOP_DATAPATH(
    input logic sysclk,
    input logic reset, 
    // input logic hog_done,
    input logic [8:0] POINTER_X,
    input logic [7:0] POINTER_Y,
    input logic GESTURE_HAND,

    output logic tx_out
    );

logic [7:0] w_tx_data;
logic w_start_trigger;
logic w_tx_stop;

fifo_uart u_fifo_uart(
    .clk(sysclk),
    .reset(reset),
    .uart_rx_in(),
    .sw_mode(),

    .measure_done(0),

    .tx_data(w_tx_data),
    .start_trigger(w_start_trigger),
    
    
    // output rd,
    .uart_tx_out(tx_out),
    .fifo_rx_data(),

    .tx_stop(w_tx_stop)

);

ControlUnit_UART u_ControlUnit(
    .clk(sysclk),
    .reset(reset),

    .tx_state_stop(w_tx_stop),
    // .HOG_DONE(hog_done),

    .point_x(POINTER_X),
    .point_y(POINTER_Y),
    .gesture(GESTURE_HAND),


    .start_trigger(w_start_trigger),
    .UART_TX_DATA(w_tx_data)
    );
endmodule
