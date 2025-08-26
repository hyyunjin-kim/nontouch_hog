`timescale 1ns / 1ps



module rgb565_go_rgb888(
    input  logic        pixel_clk,
    input  logic [ 4:0] red,
    input  logic [ 5:0] green,
    input  logic [ 4:0] blue,
    output logic [23:0] rgb888
);  
    logic [7:0] r8, g8, b8;

    always_ff @(posedge pixel_clk) begin
        // R: 5bit → 8bit
        r8 <= {red[4:0], red[4:2]}; // 상위 + 복사
        // G: 6bit → 8bit
        g8 <= {green[5:0],  green[5:4]};
        // B: 5bit → 8bit
        b8 <= {blue[4:0],   blue[4:2]};

        rgb888 <= {r8, g8, b8};
    end

endmodule