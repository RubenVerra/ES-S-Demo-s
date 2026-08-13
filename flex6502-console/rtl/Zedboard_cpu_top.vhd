library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity zedboard_cpu_top is
    Port (
        CLK100MHZ:      in  STD_LOGIC;
        btn_cpu_resetn: in  STD_LOGIC;
        uart_rx:        in  STD_LOGIC;
--        uart_tx:        out STD_LOGIC;                        -- off -> stop terminal spamming
        sw:             in  STD_LOGIC_VECTOR(1 downto 0);       -- debug
--        led:            out STD_LOGIC_VECTOR(15 downto 0);    -- debug -> zedboard has only 8 leds
        hsync:          out STD_LOGIC;
        vsync:          out STD_LOGIC;
        red:            out STD_LOGIC_VECTOR(3 downto 0);
        green:          out STD_LOGIC_VECTOR(3 downto 0);
        blue:           out STD_LOGIC_VECTOR(3 downto 0)
    );
end zedboard_cpu_top;

architecture Behavioral of zedboard_cpu_top is

    signal ab_inv:       STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal db_out_inv:   STD_LOGIC_VECTOR(7 downto 0)  := (others => '0');
    signal sync_inv:     STD_LOGIC := '0';
    signal read_inv:     STD_LOGIC := '0';

    signal db_in_inv:    STD_LOGIC_VECTOR(7 downto 0);
    signal nmi_inv, so_inv, rst_inv, irq_inv:           STD_LOGIC;
    signal test_inp_inv, rdy_inv, phi_1_inv, phi_2_inv: STD_LOGIC;

    signal out_compare:     STD_LOGIC;
    signal ab_to_pins:      STD_LOGIC_VECTOR(7 downto 0);
    signal db_out_mem:      STD_LOGIC_VECTOR(7 downto 0);
    signal curr_state:      STD_LOGIC_VECTOR(3 downto 0);
    signal cpu_running:     STD_LOGIC;

    signal s_uart_tx:       STD_LOGIC := '1';
    signal ext_rst:         STD_LOGIC;

    signal vga_byte:        STD_LOGIC_VECTOR(7 downto 0);
    signal vga_sync:        STD_LOGIC;
    signal vga_frame:       STD_LOGIC;
    signal prog_seen:       STD_LOGIC;
    signal screen_nonzero:  STD_LOGIC;

    signal led_counter:  unsigned(25 downto 0) := (others => '0');
    signal phi_counter:  unsigned(19 downto 0) := (others => '0');
    signal phi_1_prev:   STD_LOGIC := '0';

    component CPU_Test_with_Memory
    port (
        clock_master_100MHz: in  STD_LOGIC;
        ext_rst:             in  STD_LOGIC;
        ab_inv:              in  STD_LOGIC_VECTOR(15 downto 0);
        db_out_inv:          in  STD_LOGIC_VECTOR(7 downto 0);
        sync_inv:            in  STD_LOGIC;
        read_inv:            in  STD_LOGIC;
        db_in_inv:           out STD_LOGIC_VECTOR(7 downto 0);
        nmi_inv:             out STD_LOGIC;
        so_inv:              out STD_LOGIC;
        rst_inv:             out STD_LOGIC;
        irq_inv:             out STD_LOGIC;
        test_inp_inv:        out STD_LOGIC;
        rdy_inv:             out STD_LOGIC;
        phi_1_inv:           out STD_LOGIC;
        phi_2_inv:           out STD_LOGIC;
        r_Rx_Serial:         in  STD_LOGIC;
        o_Tx_Serial:         out STD_LOGIC;
        out_compare:         out STD_LOGIC;
        ab_to_pins:          out STD_LOGIC_VECTOR(7 downto 0);
        db_out_mem:          out STD_LOGIC_VECTOR(7 downto 0);
        curr_state:          out STD_LOGIC_VECTOR(3 downto 0);
        cpu_running:         out STD_LOGIC;
        prog_seen:           out STD_LOGIC;
        screen_nonzero:      out STD_LOGIC
    );
    end component;

    component uart_vga_top
    port(
        clk:          in  STD_LOGIC;
        rx:           in  STD_LOGIC;
        test_pattern: in  STD_LOGIC;
        any_nonzero:  in  STD_LOGIC;
        hsync:        out STD_LOGIC;
        vsync:        out STD_LOGIC;
        red:          out STD_LOGIC_VECTOR(3 downto 0);
        green:        out STD_LOGIC_VECTOR(3 downto 0);
        blue:         out STD_LOGIC_VECTOR(3 downto 0);
        uart_byte:    out STD_LOGIC_VECTOR(7 downto 0);
        have_sync:    out STD_LOGIC;
        frame_toggle: out STD_LOGIC
    );
    end component;

begin

    ext_rst <= not btn_cpu_resetn; -- active low

    CPU: CPU_Test_with_Memory port map(
        clock_master_100MHz => CLK100MHZ,
        ext_rst             => ext_rst,
        ab_inv              => ab_inv,
        db_out_inv          => db_out_inv,
        sync_inv            => sync_inv,
        read_inv            => read_inv,
        db_in_inv           => db_in_inv,
        nmi_inv             => nmi_inv,
        so_inv              => so_inv,
        rst_inv             => rst_inv,
        irq_inv             => irq_inv,
        test_inp_inv        => test_inp_inv,
        rdy_inv             => rdy_inv,
        phi_1_inv           => phi_1_inv,
        phi_2_inv           => phi_2_inv,
        r_Rx_Serial         => uart_rx,
        o_Tx_Serial         => s_uart_tx,
        out_compare         => out_compare,
        ab_to_pins          => ab_to_pins,
        db_out_mem          => db_out_mem,
        curr_state          => curr_state,
        cpu_running         => cpu_running,
        prog_seen           => prog_seen,
        screen_nonzero      => screen_nonzero
    );

    VGA: uart_vga_top port map(
        clk          => CLK100MHZ,
        rx           => s_uart_tx,
        test_pattern => sw(0),
        any_nonzero  => sw(1),
        hsync        => hsync,
        vsync        => vsync,
        red          => red,
        green        => green,
        blue         => blue,
        uart_byte    => vga_byte,
        have_sync    => vga_sync,
        frame_toggle => vga_frame
    );

--    uart_tx <= s_uart_tx;

    -- heartbeat
--    process(CLK100MHZ)
--    begin
--        if rising_edge(CLK100MHZ) then
--            led_counter <= led_counter + 1;
--        end if;
--    end process;

    -- cpu clock heartbeat
--    process(CLK100MHZ)
--    begin
--        if rising_edge(CLK100MHZ) then
--            phi_1_prev <= not phi_1_inv;
--            if (not phi_1_inv) = '1' and phi_1_prev = '0' then
--                phi_counter <= phi_counter + 1;
--            end if;
--        end if;
--    end process;

    -- debug
    --   15      FPGA heartbeat
    --   14      6502 heartbeat
    --   13      on -> CPU left reset
    --   12      on -> $0600 program
    --   11..4   last vga byte
    --   3..2    open
    --   1       on -> VGA yncbyte
    --   0       frame blink
--    led(15) <= led_counter(25);
--    led(14) <= phi_counter(9);
--    led(13) <= cpu_running;
--    led(12) <= prog_seen and screen_nonzero;
--    led(11 downto 4) <= vga_byte;
--    led(3)  <= '0';
--    led(2)  <= '0';
--    led(1)  <= vga_sync;
--    led(0)  <= vga_frame;

end Behavioral;
