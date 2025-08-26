`timescale 1ns / 1ps

module QVGA_MemController (
    input  logic        clk,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    input  logic        DE,
    // frame buffer side
    output logic        d_en,
    output logic [16:0] rAddr,
    input  logic [15:0] rData,
    // export side
    output logic [ 4:0] red_port,
    output logic [ 5:0] green_port,
    output logic [ 4:0] blue_port
);
    logic display_en;

    assign display_en = ((x_pixel < 320) && (y_pixel < 240));
    assign d_en = display_en;

    assign rAddr = display_en ? (y_pixel * 320 + x_pixel) : 0;

    assign {red_port, green_port, blue_port} = display_en ? 
        {rData[15:11], rData[10:5], rData[4:0]} : 16'b0;

    

endmodule
