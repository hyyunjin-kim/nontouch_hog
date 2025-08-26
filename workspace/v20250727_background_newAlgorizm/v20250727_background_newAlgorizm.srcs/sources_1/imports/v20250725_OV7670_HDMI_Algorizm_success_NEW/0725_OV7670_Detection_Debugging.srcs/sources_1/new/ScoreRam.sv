`timescale 1ns / 1ps
module ScoreRam #(
  parameter int TPL_NUM = 48,               // 템플릿 개수
  parameter int W       = 36                // 점수 비트 폭 (signed)
) (
  input  logic                 clk,
  input  logic                 reset,
  // write port
  input  logic                 wr_en,
  input  logic [$clog2(TPL_NUM)-1:0] wr_addr,
  input  logic signed [W-1:0]  wr_data,
  // read port
  input  logic                 rd_en,
  input  logic [$clog2(TPL_NUM)-1:0] rd_addr,
  output logic signed [W-1:0]  rd_data
);

  // 내부 메모리
  logic signed [W-1:0] mem [0:TPL_NUM-1];

  // write logic
  always_ff @(posedge clk) begin
    if (reset) begin
      // 초기화: 0으로 클리어
      for (int i = 0; i < TPL_NUM; i++)
        mem[i] <= '0;
    end
    else if (wr_en) begin
      mem[wr_addr] <= wr_data;
    end
  end

  // read logic (1clk 지연)
  always_ff @(posedge clk) begin
    if (rd_en)
      rd_data <= mem[rd_addr];
    else
      rd_data <= '0;
  end

endmodule
