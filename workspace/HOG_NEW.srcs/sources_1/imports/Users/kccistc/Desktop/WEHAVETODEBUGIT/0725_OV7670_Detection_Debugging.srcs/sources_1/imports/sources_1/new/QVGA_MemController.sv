`timescale 1ns / 1ps

module QVGA_MemController (
    input  logic        clk,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    // input  logic        DE,
    // frame buffer side
    input logic [8:0] hand_x,
    input logic [7:0] hand_y,
    input logic       hand_motion,
    output logic        d_en,
    output logic [16:0] rAddr,
    input  logic [15:0] rData,
    // export side
    output logic [ 4:0] red_out,
    output logic [ 5:0] green_out,
    output logic [ 4:0] blue_out,
    output logic [9:0] x_OV,
    output logic [9:0] y_OV);
    logic display_en;
    assign display_en = ((x_pixel < 320) && (y_pixel < 240));
    assign d_en = display_en;
    assign x_OV = x_pixel;
    assign y_OV = y_pixel;

    assign rAddr = display_en ? (y_pixel * 320 + x_pixel) : 0;
    logic [ 4:0] red_port;
    logic [ 5:0] green_port;
    logic [ 4:0] blue_port;


    assign {red_port, green_port, blue_port} = display_en ? 
        {rData[15:11], rData[10:5], rData[4:0]} : 16'b0;

Box_Drawer_RGB565_Overlay u_box_make(
    .clk(clk),
    .de(display_en),
    .vga_x(x_pixel),
    .vga_y(y_pixel),
    .obj_x(hand_x),
    .obj_y(hand_y),
    .gesture(hand_motion),    // 0: blue, 1: red
    .frame_r(red_port),         // 배경 프레임 Red
    .frame_g(green_port),         // 배경 프레임 Green
    .frame_b(blue_port),         // 배경 프레임 Blue
    .vga_r(red_out),
    .vga_g(green_out),
    .vga_b(blue_out)
);
    

endmodule
