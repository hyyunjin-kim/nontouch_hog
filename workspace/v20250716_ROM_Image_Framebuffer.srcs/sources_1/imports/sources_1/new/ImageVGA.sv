`timescale 1ns / 1ps

module ImageVGA (
    input logic clk,
    input logic rst,
    output logic h_sync,
    output logic v_sync,
    // output logic [3:0] g_red_port,
    // output logic [3:0] g_green_port,
    // output logic [3:0] g_blue_port
    // input  logic [3:0] sw_red,
    // input  logic [3:0] sw_green,
    // input  logic [3:0] sw_blue,
    // input  logic       gray_sw
    output logic [3:0] f_red_port,
    output logic [3:0] f_green_port,
    output logic [3:0] f_blue_port
);

    logic       DE;
    logic [9:0] x_pixel;
    logic [9:0] y_pixel;
    logic [3:0] red_port;
    logic [3:0] green_port;
    logic [3:0] blue_port;
    logic [3:0] g_red_port, g_blue_port, g_green_port;
    logic [16:0] Addr;
    logic [11:0] rData;

    assign Addr = y_pixel*320+x_pixel;
    assign f_red_port = rData[11:8];
    assign f_green_port = rData[7:4];
    assign f_blue_port = rData[3:0];

    VGA_Controller U_VGA_Controller (.*);
    Image_rom U_Image_rom (.*);
    grayscale U_Grayscale (.*);
    Frame_buffer U_Framebuffer(
            // write side
            .rst(rst),
            .wclk(clk),
            .we(DE),
            .wAddr(Addr),
            .wData({g_red_port,g_green_port,g_blue_port}),
            // read side
            .rclk(clk),
            .oe(DE),
            .rAddr(Addr),
            .rData(rData)
    );
endmodule

module grayscale (
    input logic [3:0] red_port,
    input logic [3:0] green_port,
    input logic [3:0] blue_port,
    //input logic       gray_sw,
    output logic [3:0] g_red_port,
    output logic [3:0] g_green_port,
    output logic [3:0] g_blue_port
);
    // logic [3:0] gray_red_port;
    // logic [3:0] gray_green_port;
    // logic [3:0] gray_blue_port;

    assign g_red_port = {(77*red_port) + (150*green_port) + (29*blue_port)}[11:8];
    assign g_green_port = {(77*red_port) + (150*green_port) + (29*blue_port)}[11:8];
    assign g_blue_port = {(77*red_port) + (150*green_port) + (29*blue_port)}[11:8];

    // always_comb begin
    //     if(gray_sw) begin
    //         g_red_port = gray_red_port ;
    //         g_green_port = gray_green_port;
    //         g_blue_port = gray_blue_port;
    //     end else begin
    //         g_red_port = red_port;
    //         g_green_port = green_port;
    //         g_blue_port = blue_port;
    //     end
    // end
endmodule