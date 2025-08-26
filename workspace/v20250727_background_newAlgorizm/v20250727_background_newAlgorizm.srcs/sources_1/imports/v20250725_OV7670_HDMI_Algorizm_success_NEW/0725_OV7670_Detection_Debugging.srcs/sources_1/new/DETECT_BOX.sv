`timescale 1ns / 1ps


module Box_Drawer_RGB565_Overlay (
    input  logic        clk,
    input  logic [9:0]  vga_x,
    input  logic [9:0]  vga_y,
    input  logic [8:0]  obj_x,
    input  logic [7:0]  obj_y,
    input  logic        gesture,         // 0: blue, 1: red
    input  logic [4:0]  frame_r,         // 배경 프레임 Red
    input  logic [5:0]  frame_g,         // 배경 프레임 Green
    input  logic [4:0]  frame_b,         // 배경 프레임 Blue
    output logic [4:0]  vga_r,           // 출력 Red
    output logic [5:0]  vga_g,           // 출력 Green
    output logic [4:0]  vga_b            // 출력 Blue
);

    parameter BOX_SIZE = 20;

    logic draw_box;

    always_comb begin
        draw_box = (
            vga_x >= obj_x && vga_x < obj_x + BOX_SIZE &&
            vga_y >= obj_y && vga_y < obj_y + BOX_SIZE
        );

        if (draw_box) begin
            // 박스 색상
            if (gesture == 1) begin
                vga_r = 5'b11111;
                vga_g = 6'b000000;
                vga_b = 5'b00000;
            end else begin
                vga_r = 5'b00000;
                vga_g = 6'b000000;
                vga_b = 5'b11111;
            end
        end else begin
            // 기존 영상 그대로 통과
            vga_r = frame_r;
            vga_g = frame_g;
            vga_b = frame_b;
        end
    end

endmodule
