module Box_Drawer_RGB565_Overlay (
    input  logic        clk,
    input  logic [9:0]  vga_x,
    input  logic [9:0]  vga_y,
    input  logic [8:0]  obj_x,
    input  logic [7:0]  obj_y,
    input  logic        gesture,         // 0: blue, 1: red
    input  logic [4:0]  frame_r,
    input  logic [5:0]  frame_g,
    input  logic [4:0]  frame_b,
    input  logic        de,
    output logic [4:0]  vga_r,
    output logic [5:0]  vga_g,
    output logic [4:0]  vga_b
);
    parameter BOX_SIZE = 20;
    logic draw_box;
    logic box_edge;

    // 박스 영역 안인지
    always_comb begin
        draw_box = (vga_x >= obj_x && vga_x < obj_x + BOX_SIZE &&
                    vga_y >= obj_y && vga_y < obj_y + BOX_SIZE);

        // 테두리 조건: 박스 경계선 (4변)
        box_edge = draw_box &&
                   (vga_x == obj_x || vga_x == obj_x + BOX_SIZE - 1 ||
                    vga_y == obj_y || vga_y == obj_y + BOX_SIZE - 1);
    end

    always_ff @(posedge clk) begin
        if (de) begin
            if (box_edge) begin
                if (gesture) begin
                    // 빨간 테두리
                    vga_r <= 5'b11111;
                    vga_g <= 6'b000000;
                    vga_b <= 5'b00000;
                end else begin
                    // 파란 테두리
                    vga_r <= 5'b00000;
                    vga_g <= 6'b000000;
                    vga_b <= 5'b11111;
                end
            end else begin
                // 원본 색상 그대로
                vga_r <= frame_r;
                vga_g <= frame_g;
                vga_b <= frame_b;
            end
        end
    end
endmodule
