`timescale 1ns / 1ps


module Dot_Cal (
  input logic clk,
  input logic reset,
  input  logic        blk_valid,           // 블록 디스크립터 유효
  input  logic [15:0] tpl_out [0:15],  // Template HOG 메모리 인터페이스
  input  logic [15:0] person_out [0:15],
  output logic signed [35:0] cos_q,    // Q1.15 포맷
  output logic valid_out
);
  // 1) 내적
  logic signed [31:0] prod [0:15];
  logic signed [35:0] dot;
  genvar i;
  generate
    for (i = 0; i < 16; i++) begin : MUL
      // Vivado에 “DSP48E1로 구현해 달라”고 힌트 주기
      (* use_dsp = "yes" *) 
      always_ff @(posedge clk) begin
        prod[i] <= tpl_out[i] * person_out[i];
      end
    end
  endgenerate

  // 내적 곱셈 입력이 유효할 때 prod_valid 를 1클록에 걸쳐 함께 발생
logic prod_valid = blk_valid;
// 4클록 지연 레지스터
logic [3:0] valid_shifter;

always_ff @(posedge clk or posedge reset) begin
  if (reset) valid_shifter <= 0;
  else       valid_shifter <= {valid_shifter[2:0], prod_valid};
end

assign valid_out = valid_shifter[3];


Dot_AdderTree #(.DW(32) ) U_AdderTree(
  .clk(clk),
  .reset(reset),
  .prod(prod),
  .dot(dot)  // 넉넉히 버스 폭 확장
);

assign cos_q = dot;

endmodule

module Dot_AdderTree #(
  parameter int DW = 32  // prod[] 폭
)(
  input  logic           clk,
  input  logic           reset,
  input  logic signed [DW-1:0] prod [0:15],
  output logic signed [DW+4:0] dot  // 넉넉히 버스 폭 확장
);

  // LEVEL0: 16 → 8
  logic signed [DW:0] sum0 [0:7];
  always_ff @(posedge clk) begin
    if (reset) begin
      sum0 <= '{default:0};
    end else begin
      for (int i = 0; i < 8; i++) begin
        sum0[i] <= prod[2*i] + prod[2*i+1];
      end
    end
  end

  // LEVEL1: 8 → 4
  logic signed [DW+1:0] sum1 [0:3];
  always_ff @(posedge clk) begin
    if (reset) begin
      sum1 <= '{default:0};
    end else begin
      for (int i = 0; i < 4; i++) begin
        sum1[i] <= sum0[2*i] + sum0[2*i+1];
      end
    end
  end

  // LEVEL2: 4 → 2
  logic signed [DW+2:0] sum2 [0:1];
  always_ff @(posedge clk) begin
    if (reset) begin
      sum2 <= '{default:0};
    end else begin
      sum2[0] <= sum1[0] + sum1[1];
      sum2[1] <= sum1[2] + sum1[3];
    end
  end

  // LEVEL3: 2 → 1 최종 누산
  always_ff @(posedge clk) begin
    if (reset) begin
      dot <= 0;
    end else begin
      dot <= sum2[0] + sum2[1];
    end
  end

endmodule
