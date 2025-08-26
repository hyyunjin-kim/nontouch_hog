`timescale 1ns / 1ps


module ROI_Extracter(
    input logic clk,
    input logic reset,
    input logic mask_out,
    input  logic [9:0] x_in, y_in,
    input logic frame_end,
    output logic [9:0] min_x,
    output logic [9:0] min_y,
    output logic [9:0] max_x,
    output logic [9:0] max_y,
    output logic roi_valid
    );

    logic [9:0] min_x_reg, min_y_reg, max_x_reg, max_y_reg,roi_valid_reg;
    // logic [$clog2(320*240) -1 :0] cnt;

    always_ff @( posedge clk ) begin : accumulate_coordinate
        if (reset) begin
            min_x_reg <= 10'd319;
            min_y_reg <= 10'd239;
            max_x_reg <= 10'd0;
            max_y_reg <= 10'd0;
            // cnt       <= 0;
            roi_valid_reg <=0;
        end
        else begin
            // cnt <= cnt +1;
            if (mask_out) begin
            if (x_in < min_x_reg) min_x_reg <= x_in;
            if (x_in > max_x_reg) max_x_reg <= x_in;
            if (y_in < min_y_reg) min_y_reg <= y_in;
            if (y_in > max_y_reg) max_y_reg <= y_in;
             end

            if (frame_end) begin
              min_x <= min_x_reg;
              min_y <= min_y_reg;
              max_x <= max_x_reg;
              max_y <= max_y_reg;
               roi_valid_reg <= 1'b1;
              // 다음 프레임을 위해 초기화
              min_x_reg <= 10'd319;
              min_y_reg <= 10'd239;
              max_x_reg <= 10'd0;
              max_y_reg <= 10'd0;
            //   cnt       <= 0;
            end
            else begin
                roi_valid_reg <=0;
            end
        end
    end

assign roi_valid = roi_valid_reg;
    


endmodule
