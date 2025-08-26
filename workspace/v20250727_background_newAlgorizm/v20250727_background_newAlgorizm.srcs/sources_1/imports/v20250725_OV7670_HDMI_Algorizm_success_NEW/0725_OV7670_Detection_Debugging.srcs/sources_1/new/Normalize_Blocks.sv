module Block_Normalize (
  input  logic               clk,
  input  logic               reset,

  // Cell_Histograms 출력 (시퀀셜)
  input  logic               cell_done,
  input  logic [5:0]         cell_x,
  input logic  [4:0]         cell_y, // 셀 좌표
  input  logic [15:0]        hist0, hist1, hist2, hist3,

  output logic               blk_valid,      // 블록 디스크립터 유효
  output logic [15:0]        desc [0:15],     // 정규화된 블록 벡터
  output logic [9:0] blk_x,
  output logic [9:0] blk_y
);

  //―――― 파라미터 정의 ――――
  localparam int NCX    = 320/8;
  localparam int DATA_W = 16;
  localparam int BLEN   = 16;  // 4셀×4빈

  //―――― 2×2 셀 블록을 모아둘 라인 버퍼(이전 행) ――――
  logic [DATA_W-1:0] linebuf0 [0:NCX-1][0:3];
  logic [DATA_W-1:0] linebuf1 [0:NCX-1][0:3];

  //―――― 임시 저장용 ――――
  logic [DATA_W-1:0] curhist  [0:3];
  logic [DATA_W-1:0] block_vals [0:BLEN-1];
  logic [DATA_W-1:0] src_vals   [0:3];
  logic [DATA_W+4:0] sum;
  logic [DATA_W-1:0] recip;

  always_ff @(posedge clk) begin
    if (reset) begin
      // linebuf 초기화
      for (int x = 0; x < NCX; x++)
        for (int b = 0; b < 4; b++) begin
          linebuf0[x][b] <= 0;
          linebuf1[x][b] <= 0;
        end
      blk_valid <= 0;
    end
    else begin
      blk_valid <= 0;

      if (cell_done) begin
        // 1) 두 줄짜리 라인버퍼 갱신
        linebuf1[cell_x] <= linebuf0[cell_x];
        linebuf0[cell_x][0] <= hist0;
        linebuf0[cell_x][1] <= hist1;
        linebuf0[cell_x][2] <= hist2;
        linebuf0[cell_x][3] <= hist3;

        // 2) 셀 좌표가 (0,0) 이 아니면 2×2 블록 완성
        if (cell_x > 0 && cell_y > 0) begin
          int idx = 0;
          for (int dy = 1; dy >= 0; dy--) begin
            for (int dx = 1; dx >= 0; dx--) begin
              // dy/dx 에 따라 src_vals 복사
              if (dy == 1) begin
                // 윗줄: linebuf1
                src_vals = linebuf1[cell_x - dx];
              end else begin
                // 아랫줄: linebuf0
                src_vals = linebuf0[cell_x - dx];
              end

              // 4bin → block_vals
              for (int b = 0; b < 4; b++)
                block_vals[idx++] = src_vals[b];
            end
          end

          // 3) L1 norm(sum of abs)
          sum = 0;
          for (int i = 0; i < BLEN; i++)
            sum += block_vals[i];

          // 4) reciprocal 근사
          recip = (sum != 0) ? ((1 << DATA_W) / sum) : 0;

          // 5) normalization & 출력 버퍼에 저장
           // normalization + 좌표/유효신호
          begin
            for (int i = 0; i < BLEN; i++)
              desc[i] <= (block_vals[i] * recip) >> DATA_W;
            blk_x      <= (cell_x - 1) * 8;
            blk_y      <= (cell_y - 1) * 8;
            blk_valid  <= 1;
          end
        end
      end
    end
  end

endmodule
