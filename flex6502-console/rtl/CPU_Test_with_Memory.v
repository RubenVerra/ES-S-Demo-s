`timescale 1ns / 1ps

module CPU_Test_with_Memory #(
    // Het pad naar het geheugenimage staat in snake_config.vh, niet hier.
    parameter CPU_DIVISOR   = 50,   // CPU-klok = 100 MHz / (CPU_DIVISOR * clk_coeff)
    parameter CLKS_PER_BIT  = 869   // 100 MHz / 115200 baud
                                    // in simulatie mag je beide veel kleiner
                                    // zetten, dan is een frame snel klaar
)(
    input             clock_master_100MHz,
    input             ext_rst,            // knop CPU_RESET, actief hoog

    // uitgangen van de externe chip (niet gebruikt als de RTL-core draait)
    input      [15:0] ab_inv,
    input      [7:0]  db_out_inv,
    input             sync_inv, read_inv,

    // ingangen naar de externe chip
    output     [7:0]  db_in_inv,
    output            nmi_inv, so_inv, rst_inv, irq_inv,
    output            test_inp_inv, rdy_inv, phi_1_inv, phi_2_inv,

    // UART
    input             r_Rx_Serial,
    output            o_Tx_Serial,

    output reg        out_compare,

    // debug
    output     [7:0]  ab_to_pins,
    output     [7:0]  db_out_mem,
    output     [3:0]  curr_state,
    output            cpu_running,
    output            prog_seen,       // CPU haalt code uit $0600
    output            screen_nonzero   // er staat iets in het schermgeheugen
    );

    //---------------------
    // besturingssignalen
    //---------------------
    wire test_inp;
    wire cpu_rst_n;

    wire rdy = 1'b1;
    wire rst = cpu_rst_n;      // actief laag: 0 = reset
    wire irq = 1'b0;
    wire nmi = 1'b0;
    wire so  = 1'b0;

    assign cpu_running = cpu_rst_n;

    //-------
    // klok
    //-------
    wire [17:0] clk_coeff;
    wire        clock_enable;
    wire        phi_1, phi_2;

    clock_generator #(.DIVISOR_1(CPU_DIVISOR), .phase_diff(8)) my_clk_gen (
        .clock_master_100MHz(clock_master_100MHz),
        .DIVISOR_2(clk_coeff),
        .clock_enable(clock_enable),
        .phi_1(phi_1), .phi_2(phi_2));

    //--------------------
    // 6502 (RTL-versie)
    //--------------------
    wire [15:0] ab_rtl;
    wire        read_rtl, sync_rtl;
    wire [7:0]  db_out_rtl;
    wire [7:0]  db_in;

    flex6502 my_dut_rtl (
        .phi_1(phi_1), .phi_2(phi_2), .db_in(db_in),
        .rdy(rdy), .rst(rst), .irq(irq), .nmi(nmi), .so(so),
        .db_out(db_out_rtl), .ab(ab_rtl), .sync(sync_rtl), .read(read_rtl),
        .test_inp(test_inp));

    //-----------------------------
    // signalen richting geheugen
    //-----------------------------
    wire [15:0] ab_mem   = ab_rtl;
    wire        read_mem = read_rtl;
    wire        sync_mem = sync_rtl;
    assign      db_out_mem = db_out_rtl;
    assign      ab_to_pins = ab_mem[7:0];

    assign db_in_inv    = ~db_in;
    assign nmi_inv      = ~nmi;
    assign so_inv       = ~so;
    assign rst_inv      = ~rst;
    assign irq_inv      = ~irq;
    assign rdy_inv      = ~rdy;
    assign phi_1_inv    = ~phi_1;
    assign phi_2_inv    = ~phi_2;
    assign test_inp_inv = ~test_inp;

    always @(posedge phi_1) out_compare <= 1'b0;

    wire       Rx_DV;
    wire [7:0] Rx_Byte;

    UART_setup_console #(.CLKS_PER_BIT(CLKS_PER_BIT)) my_uart_setup_console (
        .clock_master_100MHz(clock_master_100MHz),
        .phi_1(phi_1), .phi_2(phi_2), .sync_mem(sync_mem),
        .ab_from_cpu(ab_mem[14:0]),
        .db_from_cpu(db_out_mem),
        .read(read_mem),
        .en_RNG(1'b1),
        .r_Rx_Serial(r_Rx_Serial),
        .o_Tx_Serial(o_Tx_Serial),
        .db_to_cpu(db_in),
        .clk_coeff(clk_coeff),
        .curr_state(curr_state),
        .test_inp(test_inp),
        .clock_enable(clock_enable),
        .Rx_DV(Rx_DV),
        .Rx_Byte(Rx_Byte),
        .cpu_rst_n(cpu_rst_n),
        .ext_rst(ext_rst),
        .prog_seen(prog_seen),
        .screen_nonzero(screen_nonzero));

endmodule
