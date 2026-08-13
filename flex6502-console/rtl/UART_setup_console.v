`timescale 1ns / 1ps

module UART_setup_console #(
    parameter CLKS_PER_BIT     = 869,     // 100MHz / 115200 baud
    parameter CLKS_PER_BIT_TX  = 87,      // zenden naar de VGA:  1,15 Mbaud
    parameter SCREEN_BASE   = 15'h0200,   // scherm $0200..$05FF
    parameter SCREEN_BYTES  = 1024,       // 32 x 32
    parameter [7:0] SYNC_BYTE = 8'hFF,    // framemarkering
    parameter RNG_ADDR      = 15'h00FE,   // random byte 1 -> appel X
    parameter RNG2_ADDR     = 15'h00FD,   // random byte 2 -> appel Y
    parameter KEY_ADDR      = 15'h00FF,   // laatste toets
    parameter RESET_PHI_EDGES = 6'd40     // CPU-klokken dat reset laag blijft
)(
    input             clock_master_100MHz,
    input             phi_1, phi_2, sync_mem,

    input      [14:0] ab_from_cpu,
    input      [7:0]  db_from_cpu,
    input             read,
    input             en_RNG,

    input             r_Rx_Serial,
    output            o_Tx_Serial,

    output     [7:0]  db_to_cpu,
    output reg [17:0] clk_coeff    = 18'd20,   // CPU-klok 100 kHz
    output reg [3:0]  curr_state   = 4'd0,
    output reg        test_inp     = 1'b0,
    output reg        clock_enable = 1'b1,

    output            Rx_DV,
    output     [7:0]  Rx_Byte,

    output reg        cpu_rst_n      = 1'b0, // actief laag, naar de 6502
    input             ext_rst,               // resetknop, actief hoog

    // debug
    output reg        prog_seen      = 1'b0, // CPU haalt code uit $0600
    output reg        screen_nonzero = 1'b0  // er staat iets op het scherm
    );

    //-----------
    // Geheugen
    //-----------
    reg         web  = 1'b0;
    reg  [14:0] ab_b = 15'd0;
    reg  [7:0]  dib  = 8'd0;
    wire [7:0]  dob;

    memory_dual_port my_memory (
        .clka (phi_2),                 // CPU-kant
        .clkb (clock_master_100MHz),   // FPGA-kant
        .ena  (1'b1), .enb (1'b1),
        .wea  (~read), .web (web),
        .addra(ab_from_cpu), .addrb(ab_b),
        .dia  (db_from_cpu), .dib (dib),
        .doa  (db_to_cpu),   .dob (dob)
    );

    //-------
    // UART
    //-------
    wire       Tx_Done;
    reg  [7:0] Tx_Byte = 8'd0;
    reg        Tx_DV   = 1'b0;

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) UART_RX_INST (
        .i_Clock(clock_master_100MHz),
        .i_Rx_Serial(r_Rx_Serial),
        .o_Rx_DV(Rx_DV),
        .o_Rx_Byte(Rx_Byte));

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT_TX)) UART_TX_INST (
        .i_Clock(clock_master_100MHz),
        .i_Tx_DV(Tx_DV),
        .i_Tx_Byte(Tx_Byte),
        .o_Tx_Active(),
        .o_Tx_Serial(o_Tx_Serial),
        .o_Tx_Done(Tx_Done));

    //---------------------------
    // Toetsen latch + snelheid
    //---------------------------
    reg [7:0] key_latch = 8'd0;
    wire      soft_reset = Rx_DV && (Rx_Byte == 8'h72);   // 'r'

    // Toets blijft staan tot 6502 hem ophaalt.
    wire key_consumed = web && (ab_b == KEY_ADDR);
    reg  key_pending  = 1'b0;

    always @(posedge clock_master_100MHz) begin
        if (Rx_DV) begin
            case (Rx_Byte)
                8'h77, 8'h61, 8'h73, 8'h64: begin                  // w a s d
                    key_latch   <= Rx_Byte;
                    key_pending <= 1'b1;
                end
                8'h39: clk_coeff <= 18'd22;
                8'h38: clk_coeff <= 18'd25;
                8'h37: clk_coeff <= 18'd28;
                8'h36: clk_coeff <= 18'd33;
                8'h35: clk_coeff <= 18'd40;
                8'h34: clk_coeff <= 18'd50;
                8'h33: clk_coeff <= 18'd66;
                8'h32: clk_coeff <= 18'd100;
                8'h31: clk_coeff <= 18'd200;
                8'h30: clk_coeff <= 18'd20;
                8'h6a: clk_coeff <= 18'd2000;   // 'j' heel traag
                8'h6b: clk_coeff <= 18'd500;    // 'k'
                8'h6c: clk_coeff <= 18'd286;    // 'l'
                default: ;
            endcase
        end else if (key_consumed) begin
            key_pending <= 1'b0;    // doorgegeven, wachten op de volgende druk
        end
        test_inp     <= 1'b0;
        clock_enable <= 1'b1;       // de CPU loopt continu door
    end

    //------
    // RNG
    //------
    reg [31:0] lfsr = 32'hACE1_2345;

    always @(posedge clock_master_100MHz) begin
        if (en_RNG)
            lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
    end

    wire [7:0] rng_a = lfsr[7:0];
    wire [7:0] rng_b = lfsr[23:16] ^ lfsr[15:8];

    //------------
    // CPU reset
    //------------
    reg       phi2_d      = 1'b0;
    reg [5:0] rst_phi_cnt = 6'd0;

    always @(posedge clock_master_100MHz) begin
        phi2_d <= phi_2;
        if (soft_reset || ext_rst) begin
            rst_phi_cnt <= 6'd0;
            cpu_rst_n   <= 1'b0;
        end else if (rst_phi_cnt < RESET_PHI_EDGES) begin
            if (phi_2 && !phi2_d) rst_phi_cnt <= rst_phi_cnt + 6'd1;
            cpu_rst_n <= 1'b0;
        end else begin
            cpu_rst_n <= 1'b1;
        end
    end

    //-------------
    // LEDs debug
    //-------------
    reg [14:0] ab_s1 = 0, ab_s2 = 0, ab_s3 = 0;
    wire       ab_stable = (ab_s1 == ab_s2) && (ab_s2 == ab_s3);

    always @(posedge clock_master_100MHz) begin
        ab_s1 <= ab_from_cpu;
        ab_s2 <= ab_s1;
        ab_s3 <= ab_s2;
        if (soft_reset || ext_rst)
            prog_seen <= 1'b0;
        else if (ab_stable && (ab_s3[14:8] == 7'h06 || ab_s3[14:8] == 7'h07))
            prog_seen <= 1'b1;
    end

    //--------
    // Frame
    //--------
    localparam S_SYNC_TX   = 4'd0;   // syncbyte 0xFF
    localparam S_SYNC_WAIT = 4'd1;
    localparam S_ADDR      = 4'd2;   // adres op RAM zetten
    localparam S_WAIT1     = 4'd3;   // latency van RAM
    localparam S_WAIT2     = 4'd4;
    localparam S_LATCH     = 4'd5;   // dob overnemen in Tx_Byte
    localparam S_TX        = 4'd6;   // Tx_DV precies 1 klok hoog
    localparam S_TXWAIT    = 4'd7;   // wachten tot byte weg is
    localparam S_WR_RNG    = 4'd8;   // $00FE <- rng_a
    localparam S_WR_RNG2   = 4'd9;   // $00FD <- rng_b
    localparam S_WR_KEY    = 4'd10;  // $00FF <- laatste toets
    localparam S_WR_END    = 4'd11;

    reg [10:0] idx = 11'd0;          // 0..1023

    always @(posedge clock_master_100MHz) begin
        if (soft_reset || ext_rst) begin
            curr_state     <= S_SYNC_TX;
            idx            <= 11'd0;
            Tx_DV          <= 1'b0;
            web            <= 1'b0;
            screen_nonzero <= 1'b0;
        end else begin
            Tx_DV <= 1'b0;
            web   <= 1'b0;

            case (curr_state)
                S_SYNC_TX: begin
                    Tx_Byte    <= SYNC_BYTE;
                    idx        <= 11'd0;
                    Tx_DV      <= 1'b1;
                    curr_state <= S_SYNC_WAIT;
                end

                S_SYNC_WAIT: if (Tx_Done) curr_state <= S_ADDR;

                S_ADDR: begin
                    ab_b       <= SCREEN_BASE + idx;
                    curr_state <= S_WAIT1;
                end

                S_WAIT1: curr_state <= S_WAIT2;
                S_WAIT2: curr_state <= S_LATCH;

                S_LATCH: begin
                    Tx_Byte    <= dob;
                    if (dob != 8'h00) screen_nonzero <= 1'b1;
                    curr_state <= S_TX;
                end
                S_TX: begin
                    Tx_DV      <= 1'b1;
                    curr_state <= S_TXWAIT;
                end
                S_TXWAIT: begin
                    if (Tx_Done) begin
                        if (idx == SCREEN_BYTES-1) begin
                            curr_state <= S_WR_RNG;
                        end else begin
                            idx        <= idx + 11'd1;
                            curr_state <= S_ADDR;
                        end
                    end
                end
                S_WR_RNG: begin
                    web        <= 1'b1;
                    ab_b       <= RNG_ADDR;
                    dib        <= rng_a;
                    curr_state <= S_WR_RNG2;
                end
                S_WR_RNG2: begin
                    web        <= 1'b1;
                    ab_b       <= RNG2_ADDR;
                    dib        <= rng_b;
                    curr_state <= S_WR_KEY;
                end
                S_WR_KEY: begin
                    if (key_pending) begin
                        web  <= 1'b1;
                        ab_b <= KEY_ADDR;
                        dib  <= key_latch;
                    end
                    curr_state <= S_WR_END;
                end

                S_WR_END: curr_state <= S_SYNC_TX;

                default: curr_state <= S_SYNC_TX;

            endcase
        end
    end

endmodule
