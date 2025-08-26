`timescale 1ns / 1ps

module QVGA_MemController (
    // VGA Controller side
    input  logic        clk,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    input  logic        DE,
    // frame buffer side
    output logic        rclk,
    output logic        d_en,
    output logic [16:0] rAddr,
    input  logic [15:0] rData,
    // export side
    output logic [ 4:0] red_port,
    output logic [ 5:0] green_port,
    output logic [ 4:0] blue_port
    // isp
    // input logic sw // upscale mode sw
    // input logic [3:0] sw_red,
    // input logic [3:0] sw_green,
    // input logic [3:0] sw_blue
);

    logic display_en;

    assign rclk = clk;
    // assign display_en = sw ? (x_pixel < 320 && y_pixel < 240) : (x_pixel < 640 && y_pixel < 480);
    assign display_en = (x_pixel < 320 && y_pixel < 240);
    assign d_en = display_en;

    assign rAddr = (x_pixel < 320 && y_pixel < 240) ? (y_pixel * 320 + x_pixel) : 16'b0;

    // reg [16:0] down_rAddr = (x_pixel < 320 && y_pixel < 240) ? (y_pixel * 320 + x_pixel) : 16'b0;
    // reg [16:0] up_rAddr = (x_pixel < 640 && y_pixel < 480) ? ((y_pixel/2) * 320 + x_pixel/2) : 16'b0;
    //assign rAddr = sw ? down_rAddr : up_rAddr;

    assign {red_port, green_port, blue_port} = display_en ? {rData[15:11], rData[10:5],rData[4:0]} : 16'b0;
    
endmodule
