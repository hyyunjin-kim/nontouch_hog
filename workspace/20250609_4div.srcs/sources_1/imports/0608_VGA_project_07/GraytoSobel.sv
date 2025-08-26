`timescale 1ns / 1ps



/*module GraytoSobel (
    input  logic        clk,
    input  logic        reset,
    input  logic [11:0] pixel_in, 
    input  logic [16:0] addr,     
    output logic [3:0] edge_red,
    output logic [3:0] edge_green,
    output logic [3:0] edge_blue 
);
    logic [3:0] line_buffer[2:0][159:0]; 

    logic [3:0] p[0:8];
    logic [11:0] edge_out;
    assign {edge_red, edge_green, edge_blue} = edge_out;

    logic [7:0] row, col;
    assign row = addr / 160;
    assign col = addr % 160;

    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < 3; i++) begin
                for (int j = 0; j < 160; j++) begin
                    line_buffer[i][j] <= 0;
                end
            end
        end else begin
            line_buffer[2][col] <= line_buffer[1][col];
            line_buffer[1][col] <= line_buffer[0][col];
            line_buffer[0][col] <= pixel_in[11:8];     
            
        end
    end

    always_ff @(posedge clk) begin
        // 윈도우의 위쪽 행 (line_buffer[2])
        p[0] <= (row == 0 || col == 0) ? 0 : line_buffer[2][col-1];
        p[1] <= (row == 0) ? 0 : line_buffer[2][col];
        p[2] <= (row == 0 || col == 159) ? 0 : line_buffer[2][col+1];
        // 윈도우의 중간 행 (line_buffer[1])
        p[3] <= (col == 0) ? 0 : line_buffer[1][col-1];
        p[4] <= line_buffer[1][col];
        p[5] <= (col == 159) ? 0 : line_buffer[1][col+1];
        // 윈도우의 아래쪽 행 (line_buffer[0])
        p[6] <= (col == 0 || row == 119) ? 0 : line_buffer[0][col-1];
        p[7] <= (row == 119) ? 0 : line_buffer[0][col];
        p[8] <= (col == 159 || row == 119) ? 0 : line_buffer[0][col+1];
    end

    logic signed [6:0] gx, gy;
    logic [6:0] abs_gx, abs_gy;
    logic [7:0] sum;

    always_comb begin
        gx = (p[2] + 2 * p[5] + p[8]) - (p[0] + 2 * p[3] + p[6]);
        gy = (p[6] + 2 * p[7] + p[8]) - (p[0] + 2 * p[1] + p[2]);

        abs_gx = (gx < 0) ? -gx : gx;
        abs_gy = (gy < 0) ? -gy : gy;

  
        sum = abs_gx + abs_gy;

    if (sum > 9)
        edge_out = 12'hFFF; 
    else
        edge_out = 12'h000; 
end

endmodule*/