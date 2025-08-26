`timescale 1ns / 1ps

module Image_rom (
    // input  logic [3:0] sw_red,
    // input  logic [3:0] sw_green,
    // input  logic [3:0] sw_blue,

    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    input  logic       DE,
    output       [3:0] red_port,
    output       [3:0] green_port,
    output       [3:0] blue_port
);

    logic [16:0] image_addr;
    logic [15:0] image_data;  // RGB565 data => 16'b rrrrr_gggggg_bbbbb;

    assign image_addr = (x_pixel < 320 && y_pixel <240) ? (320*y_pixel + x_pixel) : 17'd0;
    assign {red_port, green_port, blue_port} = (DE && x_pixel < 320 && y_pixel <240) ? {image_data[15:12],image_data[10:7],image_data[4:1]} : 12'b0; 
                                        // 하위비트가 더 데이터가 적기때문에 하위비트를 4bit에 맞춰버린다
    image_rom U_ROM(
        .addr(image_addr), 
        .data(image_data)
    );
endmodule



module image_rom (
    input  logic [16:0] addr,  // 640x480 = VGA // 320x240 = QVGA
    output logic [15:0] data
);
    logic [15:0] rom[0:320*240-1];  // 1 FRAME을 넣기 위한 크기

    initial begin
        $readmemh("Lenna.mem", rom); // 읽은 값을 rom에다가 넣어라.
    end

    assign data = rom[addr];  // 주소 들어가면 data 나오는 구조
endmodule

// module vga_rgb_switch (
//     input logic [3:0] sw_red,
//     input logic [3:0] sw_green,
//     input logic [3:0] sw_blue,
//     input logic       DE,
//     output logic [3:0] red_port,
//     output logic [3:0] green_port,
//     output logic [3:0] blue_port
// );
//     assign red_port = DE ? sw_red : 4'b0;
//     assign green_port = DE ? sw_green : 4'b0;
//     assign blue_port = DE ? sw_blue : 4'b0;
// endmodule