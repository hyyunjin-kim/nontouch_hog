`timescale 1ns / 1ps
`timescale 1ns/1ps
module frame_buffer #(
    parameter int H = 160,
    parameter int V = 120
)(
    //------------------------------------------------------------
    // write-side  (OV7670 PCLK = 25 MHz)
    //------------------------------------------------------------
    input  logic        rst,
    input  logic        wclk,
    input  logic        we,
    input  logic [16:0] wAddr,
    input  logic [11:0] wData,

    //------------------------------------------------------------
    // read-side   (VGA CLK = 100 MHz)
    //------------------------------------------------------------
    input  logic        rclk,
    input  logic        oe,
    input  logic [16:0] rAddr,
    output logic [11:0] rData,

    //------------------------------------------------------------
    // 스캔라인·버튼 (모두 wclk 도메인)
    //------------------------------------------------------------
    input  logic [7:0]  scan_line,
    input  logic        btn_U,
    input  logic        btn_D,
    input  logic        btn_L,
    input  logic        btn_R,

    //------------------------------------------------------------
    // 새 신호 : 현재 사분면이 선택(active)됐는가?
    //------------------------------------------------------------
    input  logic        active,

    //------------------------------------------------------------
    // 상태 출력 : freeze mode (UP/DOWN/LEFT/RIGHT/STOP/IDLE)
    //------------------------------------------------------------
    output logic [2:0]  freeze_mode
);

    //─────────────────────────────────────────────
    // 1. FSM (State = freeze_mode) – wclk 25 MHz
    //─────────────────────────────────────────────
    typedef enum logic [2:0] {
        IDLE  = 3'd0,
        UP    = 3'd1,
        DOWN  = 3'd2,
        LEFT  = 3'd3,
        RIGHT = 3'd4,
        STOP  = 3'd5
    } state_e;

    state_e state, state_next;
    assign freeze_mode = state;     // 그대로 외부로 노출

    // 다음 상태 결정
    always_comb begin
        state_next = state;

        // **선택되지 않은 사분면** → 항상 IDLE
        if (active) begin
            unique case (state)
                IDLE : begin           // 버튼으로 시작
                    if      (btn_U) state_next = UP;
                    else if (btn_D) state_next = DOWN;
                    else if (btn_L) state_next = LEFT;
                    else if (btn_R) state_next = RIGHT;
                end
                UP,DOWN  : if (scan_line == V-1) state_next = STOP;
                LEFT,RIGHT:if (scan_line == H-1) state_next = STOP;
                STOP : begin            // 결과 보존 상태
                    if      (btn_U) state_next = UP;
                    else if (btn_D) state_next = DOWN;
                    else if (btn_L) state_next = LEFT;
                    else if (btn_R) state_next = RIGHT;
                end
            endcase
        end
    end

    always_ff @(posedge wclk or posedge rst) begin
        if (rst) state <= IDLE;
        else     state <= state_next;
    end

    //─────────────────────────────────────────────
    // 2. write mask 계산
    //    active=0 → 항상 라이브(덮어쓰기 허용)
    //─────────────────────────────────────────────
    logic [7:0] x = wAddr % H;   // 0‥H-1
    logic [7:0] y = wAddr / H;   // 0‥V-1

    logic allow_write;
    always_comb begin
        if (active) begin
            unique case (state)
                UP   : allow_write = (y <  V - scan_line);
                DOWN : allow_write = (y >=     scan_line);
                LEFT : allow_write = (x <  H - scan_line);
                RIGHT: allow_write = (x >=     scan_line);
                STOP : allow_write = 1'b0;    // 결과 고정
                default : allow_write = 1'b1; // IDLE
            endcase
        end
    end

    //─────────────────────────────────────────────
    // 3. Dual-port Block RAM
    //─────────────────────────────────────────────
    logic [11:0] mem [0:H*V-1];

    // write (OV7670 25 MHz)
    always_ff @(posedge wclk)
        if (we && allow_write)
            mem[wAddr] <= wData;

    // read (VGA 100 MHz)
    always_ff @(posedge rclk)
        if (oe)
            rData <= mem[rAddr];

endmodule

