`timescale 1ns / 1ps

module Template_Match #(
  parameter int TPL_NUM     = 48,     // 전체 템플릿 개수
  parameter int PARALLEL    = 8,      // 한 번에 병렬로 처리하는 수
  parameter int VECTOR_LEN  = 16      // HOG 벡터 길이
)(
  input  logic                  clk,
  input  logic                  reset,
  input  logic                  desc_valid,
  input  logic [15:0]           desc_out [0:VECTOR_LEN-1],
  
  // ROI 좌표, 그 외 … 
  output logic [$clog2(TPL_NUM)-1:0] best_tpl_id,
  output logic signed [31:0]    best_score
);


  logic [$clog2(TPL_NUM)-1:0] scan_addr;
  logic signed [31:0]         scan_score;
  logic [$clog2(TPL_NUM)-1:0] best_id;
  logic signed [31:0]         best_val;

  //===================================================
  // 1) tpl_base: 이 블록에 대해 첫 번째 비교할 템플릿 ID
  //===================================================
  logic [$clog2(TPL_NUM)-1:0] tpl_base;

  //===================================================
  // 2) ROM으로부터 VECTOR_LEN 원소씩 꺼내 저장할 버퍼
  //    tpl_data[p][e] 은 p번째 채널, e번째 원소
  //===================================================
// ROM에서 읽어온 256비트 벡터 저장
logic [16*VECTOR_LEN-1:0] tpl_data_vec [0:PARALLEL-1];

genvar r;
generate
  for (r = 0; r < PARALLEL; r++) begin : ROM_CH
    Tpl_RomVec #(
      .TPL_NUM  (TPL_NUM),
      .DATA_W   (16)
    ) uTplRomVec (
      .tpl_id       (tpl_base + r*16),
      .tpl_data_vec (tpl_data_vec[r])
    );
  end
endgenerate

// 각 채널의 유사도 결과
logic signed [35:0] cos_q    [0:PARALLEL-1];
logic               valid_dot[0:PARALLEL-1];

// 2) unpack 해서 [채널][요소] 2차원 배열로 만들기
logic [15:0] tpl_vec [0:PARALLEL-1][0:VECTOR_LEN-1];
genvar p, e;
generate
  for (p = 0; p < PARALLEL; p++) begin : UNPACK_CH
    for (e = 0; e < VECTOR_LEN; e++) begin : UNPACK_ELEM
      // 256비트 덩어리에서 16비트씩 잘라내서 tpl_vec[p][e]에 할당
      assign tpl_vec[p][e] = tpl_data_vec[p][ e*16 +: 16 ];
    end
  end
endgenerate

// 3) 각 채널마다 Dot_Cal 인스턴스

generate
  for (p = 0; p < PARALLEL; p++) begin : DOT_CHANNEL
    Dot_Cal u_dot (
      .clk        (clk),
      .reset      (reset),
      .blk_valid  (desc_valid),
      .tpl_out    (tpl_vec[p]),      // <-- 16요소 벡터
      .person_out (desc_out),        // 같은 desc_out 벡터를 모든 채널에 넣음
      .cos_q      (cos_q[p]),
      .valid_out  (valid_dot[p])
    );
  end
endgenerate


  typedef enum logic [1:0] {  
    S_IDLE,  // 대기
    S_WRITE, // 점수 쓰기
    S_MAX    // 최고값 탐색
  } state_t;
  state_t state, next_state;

  logic [$clog2(PARALLEL)-1:0] write_cnt;

  // -------------------------
  // 3) 생성된 PARALLEL 개의 cos_q 를 메모리(Score RAM)에 기록
  //    주소 = tpl_base + p, 데이터 = cos_q[p]
  // -------------------------
  logic score_we;
  logic signed [31:0]         ScoreRam_dout;
  logic [$clog2(TPL_NUM)-1:0] score_addr;
  logic signed [31:0] score_din;
   ScoreRam #(
   .TPL_NUM (TPL_NUM),      // 템플릿 개수
   .W       (36)            // cos_q 폭에 맞춰야 합니다
 ) uScoreRam (
   .clk     (clk),
   .reset   (reset),
   // write port
   .wr_en   (score_we),
   .wr_addr (score_addr),
   .wr_data (cos_q[write_cnt][35:0]),  // W=36일 때 cos_q가 36비트라면
   // read port (최댓값 스캔할 때 사용)
   .rd_en   (state == S_MAX),
   .rd_addr (scan_addr),
   .rd_data (ScoreRam_dout)
 );

  // -------------------------
  // 4) tpl_base 관리 & ScoreRam 쓰기 제어 FSM
  //    desc_valid 이 올라오면
  //      tpl_base ← 0
  //      for p=0..PARALLEL-1:
  //         score_we    ← valid_dot[p]
  //         score_addr  ← tpl_base + p
  //         score_din   ← cos_q[p]
  //      그 다음 tpl_base += PARALLEL
  //      이 과정을 tpl_base >= TPL_NUM 어길 때까지 반복
  // -------------------------



always_ff @(posedge clk or posedge reset) begin
  if (reset) begin
    state     <= S_IDLE;
    tpl_base  <= 0;
    write_cnt <= 0;
  end else begin
    state <= next_state;
    if (state == S_WRITE) begin
      if (valid_dot[write_cnt]) begin
        score_addr <= tpl_base + write_cnt;
        score_din  <= cos_q[write_cnt];
      end
      if (write_cnt == PARALLEL-1) begin
        write_cnt <= 0;
        tpl_base  <= tpl_base + PARALLEL;
      end else begin
        write_cnt <= write_cnt + 1;
      end
    end
    else if (state == S_IDLE) begin
      tpl_base  <= 0;
      write_cnt <= 0;
    end
  end
end


  always_comb begin
    next_state = state;
    score_we = (state==S_WRITE && valid_dot[write_cnt]);
    case (state)
      S_IDLE:
        if (desc_valid) next_state = S_WRITE;
      S_WRITE:
        if (tpl_base + write_cnt >= TPL_NUM) next_state = S_MAX;
      S_MAX:
        ;  // 아래에서 최고값 검색 시작
    endcase
  end

  // -------------------------
  // 5) 최고값 찾기 (ScoreRam 전수 스캔)
  //    RAM 에서 순차적으로 점수 읽어 와서 내부 레지스터에 최대값 & 인덱스 보관
  // -------------------------


  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      scan_addr <= 0;
      best_val  <= -32'h7fffffff;
      best_id   <= 0;
    end else if (state == S_MAX) begin
      scan_score = ScoreRam_dout;  // ScoreRam 모듈에서 dout 직접 연결했다고 가정
      if (scan_score > best_val) begin
        best_val <= scan_score;
        best_id  <= scan_addr;
      end
      if (scan_addr == TPL_NUM-1) begin
        // 끝
        scan_addr <= 0;
        // 결과 출력
        best_score  <= best_val;
        best_tpl_id <= best_id;
      end else begin
        scan_addr <= scan_addr + 1;
      end
    end
  end

endmodule
