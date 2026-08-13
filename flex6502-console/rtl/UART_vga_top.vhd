library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_vga_top is
    generic(
        CLKS_PER_BIT: INTEGER := 87;   -- 1,15 Mbaud
        SYNC_BYTE:    STD_LOGIC_VECTOR(7 downto 0) := x"FF";
        CELL_W:       INTEGER := 20;                             -- 32 * 20 = 640
        CELL_H:       INTEGER := 15                              -- 32 * 15 = 480
    );
    port(
        clk:          in  STD_LOGIC;
        rx:           in  STD_LOGIC;
        test_pattern: in  STD_LOGIC;                             -- SW0: kleurbalken
        any_nonzero:  in  STD_LOGIC;                             -- SW1: alles != 0 wit
        hsync:        out STD_LOGIC;
        vsync:        out STD_LOGIC;
        red:          out STD_LOGIC_VECTOR(3 downto 0);
        green:        out STD_LOGIC_VECTOR(3 downto 0);
        blue:         out STD_LOGIC_VECTOR(3 downto 0);
        uart_byte:    out STD_LOGIC_VECTOR(7 downto 0);          -- debug: laatste byte
        have_sync:    out STD_LOGIC;                             -- debug: sync gevonden
        frame_toggle: out STD_LOGIC                              -- debug: wisselt per frame
    );
end uart_vga_top;

architecture Behavioral of uart_vga_top is

    -------------------------------
    -- framebuffer: 32 x 32 bytes
    -------------------------------
    type framebuffer_t is array(0 to 1023) of STD_LOGIC_VECTOR(7 downto 0);
    signal framebuffer: framebuffer_t := (others => x"00");

    ---------
    -- UART
    ---------
    signal uart_data:  STD_LOGIC_VECTOR(7 downto 0);
    signal uart_valid: STD_LOGIC;

    signal frame_idx:  INTEGER range 0 to 1023 := 0;
    signal filling:    STD_LOGIC := '0';
    signal synced:     STD_LOGIC := '0';
    signal frame_tog:  STD_LOGIC := '0';
    signal last_byte:  STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

    --------------
    -- pixelklok
    --------------
    signal ce_cnt: unsigned(1 downto 0) := (others => '0');
    signal ce:     STD_LOGIC := '0';

    ---------------
    -- VGA timing 
    ---------------
    signal pixel_x:   INTEGER range 0 to 1023;
    signal pixel_y:   INTEGER range 0 to 1023;
    signal line_end:  STD_LOGIC;
    signal frame_end: STD_LOGIC;
    signal video_on:  STD_LOGIC;
    signal hs:        STD_LOGIC;
    signal vs:        STD_LOGIC;

    signal cell_x: INTEGER range 0 to 31 := 0;
    signal cell_y: INTEGER range 0 to 31 := 0;
    signal col:    INTEGER range 0 to 31 := 0;
    signal row:    INTEGER range 0 to 31 := 0;

    -- Tekenset voor het menu en de score: 36 tekens van 4 bij 5 punten.
    -- Tegelcode $40..$49 zijn de cijfers 0..9, $4A..$63 de letters A..Z.
    type font_t is array(0 to 179) of STD_LOGIC_VECTOR(3 downto 0);
    constant FONT : font_t := (
        "1111", "1001", "1001", "1001", "1111", "0010", "0110", "0010",
        "0010", "0111", "1111", "0001", "1111", "1000", "1111", "1111",
        "0001", "0111", "0001", "1111", "1001", "1001", "1111", "0001",
        "0001", "1111", "1000", "1111", "0001", "1111", "1111", "1000",
        "1111", "1001", "1111", "1111", "0001", "0010", "0100", "0100",
        "1111", "1001", "1111", "1001", "1111", "1111", "1001", "1111",
        "0001", "1111", "0110", "1001", "1111", "1001", "1001", "1110",
        "1001", "1110", "1001", "1110", "0111", "1000", "1000", "1000",
        "0111", "1110", "1001", "1001", "1001", "1110", "1111", "1000",
        "1110", "1000", "1111", "1111", "1000", "1110", "1000", "1000",
        "0111", "1000", "1011", "1001", "0111", "1001", "1001", "1111",
        "1001", "1001", "1110", "0100", "0100", "0100", "1110", "0011",
        "0001", "0001", "1001", "0110", "1001", "1010", "1100", "1010",
        "1001", "1000", "1000", "1000", "1000", "1111", "1001", "1111",
        "1111", "1001", "1001", "1001", "1101", "1111", "1011", "1001",
        "0110", "1001", "1001", "1001", "0110", "1110", "1001", "1110",
        "1000", "1000", "0110", "1001", "1001", "1011", "0111", "1110",
        "1001", "1110", "1010", "1001", "0111", "1000", "0110", "0001",
        "1110", "1110", "0100", "0100", "0100", "0100", "1001", "1001",
        "1001", "1001", "0110", "1001", "1001", "1001", "0110", "0110",
        "1001", "1001", "1111", "1111", "1001", "1001", "1001", "0110",
        "1001", "1001", "1001", "1001", "0110", "0100", "0100", "1111",
        "0001", "0110", "1000", "1111");

    signal cx_d1, cx_d2: INTEGER range 0 to 31 := 0;
    signal cy_d1, cy_d2: INTEGER range 0 to 31 := 0;

    signal fb_addr: INTEGER range 0 to 1023 := 0;
    signal fb_data: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal von_d:   STD_LOGIC_VECTOR(2 downto 0) := (others => '0');
    signal hs_d:    STD_LOGIC_VECTOR(2 downto 0) := (others => '1');
    signal vs_d:    STD_LOGIC_VECTOR(2 downto 0) := (others => '1');

    signal red_r:   STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal green_r: STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal blue_r:  STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
begin
    ---------------------
    -- 25 MHz pixelklok
    ---------------------
    process(clk)
    begin
        if rising_edge(clk) then
            ce_cnt <= ce_cnt + 1;
            if ce_cnt = "11" then
                ce <= '1';
            else
                ce <= '0';
            end if;
        end if;
    end process;

    -------------------
    -- UART-ontvanger
    -------------------
    u_uart: entity work.uart_rx
        generic map (CLKS_PER_BIT => CLKS_PER_BIT)
        port map(
            i_Clock     => clk,
            i_Rx_Serial => rx,
            o_Rx_DV     => uart_valid,
            o_Rx_Byte   => uart_data
        );

    ----------------------------
    -- UART - framebuffer sync
    ----------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if uart_valid = '1' then
                last_byte <= uart_data;

                if uart_data = SYNC_BYTE then
                    -- begin van nieuw frame
                    frame_idx <= 0;
                    filling   <= '1';
                    synced    <= '1';
                    frame_tog <= not frame_tog;
                elsif filling = '1' then
                    framebuffer(frame_idx) <= uart_data;
                    if frame_idx = 1023 then
                        filling <= '0';          -- frame vol
                    else
                        frame_idx <= frame_idx + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    uart_byte    <= last_byte;
    have_sync    <= synced;
    frame_toggle <= frame_tog;

    ---------------
    -- VGA timing
    ---------------
    u_vga: entity work.vga_timing
        port map(
            clk       => clk,
            ce        => ce,
            pixel_x   => pixel_x,
            pixel_y   => pixel_y,
            line_end  => line_end,
            frame_end => frame_end,
            video_on  => video_on,
            hsync     => hs,
            vsync     => vs
        );

    -------------
    -- celcount
    -------------
    process(clk)
    begin
        if rising_edge(clk) then
            if ce = '1' then
                if frame_end = '1' then
                    cell_x  <= 0; 
                    col     <= 0;
                    cell_y  <= 0; 
                    row     <= 0;
                elsif line_end = '1' then
                    cell_x  <= 0; 
                    col     <= 0;
                    if cell_y = CELL_H-1 then
                        cell_y <= 0;
                        if row < 31 then
                            row <= row + 1;
                        end if;
                    else
                        cell_y <= cell_y + 1;
                    end if;
                elsif cell_x = CELL_W-1 then
                    cell_x <= 0;
                    if col < 31 then
                        col <= col + 1;
                    end if;
                else
                    cell_x <= cell_x + 1;
                end if;
            end if;
        end if;
    end process;

    --------------
    -- PIXEL LUT
    --------------
    process(clk)
        variable ch:    INTEGER range 0 to 63;    -- tekennummer, 0 = '0', 10 = 'A'
        variable fi:    INTEGER range 0 to 179;   -- regel in de tekenset
        variable frow:  STD_LOGIC_VECTOR(3 downto 0);
    begin
        if rising_edge(clk) then
            if ce = '1' then
                -- stage 1: adres
                fb_addr <= row * 32 + col;

                -- stage 2: synchrone leesactie
                fb_data <= framebuffer(fb_addr);

                -- positie binnen de tegel meevertragen als fb_data
                cx_d1 <= cell_x; 
                cx_d2 <= cx_d1;
                cy_d1 <= cell_y; 
                cy_d2 <= cy_d1;

                -- besturingssignalen meevertragen
                von_d <= von_d(1 downto 0) & video_on;
                hs_d  <= hs_d(1 downto 0)  & hs;
                vs_d  <= vs_d(1 downto 0)  & vs;

                -- stage 3: kleurdecodering
                if von_d(1) = '1' then
                    if test_pattern = '1' then
                        -- SW0: acht kleurbalken plus een wit kader.
                        if row = 0 or row = 31 or col = 0 or col = 31 then
                            red_r   <= x"F"; 
                            green_r <= x"F"; 
                            blue_r  <= x"F";
                        else
                            case col / 4 is
                                when 0 => 
                                    red_r   <=x"0"; 
                                    green_r <=x"0"; 
                                    blue_r  <=x"0";
                                when 1 => 
                                    red_r   <=x"0"; 
                                    green_r <=x"0"; 
                                    blue_r  <=x"F";
                                when 2 => 
                                    red_r   <=x"0"; 
                                    green_r <=x"F"; 
                                    blue_r  <=x"0";
                                when 3 => 
                                    red_r   <=x"0"; 
                                    green_r <=x"F"; 
                                    blue_r  <=x"F";
                                when 4 => 
                                    red_r   <=x"F"; 
                                    green_r <=x"0"; 
                                    blue_r  <=x"0";
                                when 5 => 
                                    red_r   <=x"F"; 
                                    green_r <=x"0"; 
                                    blue_r  <=x"F";
                                when 6 => 
                                    red_r   <=x"F"; 
                                    green_r <=x"F"; 
                                    blue_r  <=x"0";
                                when others => 
                                    red_r   <=x"F"; 
                                    green_r <=x"F"; 
                                    blue_r  <=x"F";
                            end case;
                        end if;
                    elsif any_nonzero = '1' then
                        -- SW1: elke byte die niet 0 is wordt wit.
                        if fb_data = x"00" then
                            red_r   <= x"0"; 
                            green_r <= x"0"; 
                            blue_r  <= x"0";
                        else
                            red_r   <= x"F"; 
                            green_r <= x"F"; 
                            blue_r  <= x"F";
                        end if;
                    else
                        ----------------------------------------------------
                        --  TEGELCODES
                        --    $00        leeg
                        --    $01        muur / speelveldrand
                        --    $02..$08   tetrisblokken, zeven kleuren
                        --    $09/$0A    alien, twee kleuren
                        --    $0B        kanon      $0C kogel     $0D bom
                        --    $0E        peddel     $0F bal
                        --    $11        slang (wit)
                        --    $EE        appel (rood)
                        --    $40..$49   cijfer 0..9
                        --    $4A..$63   letter A..Z
                        --    $80        gemarkeerde regel in het menu
                        ----------------------------------------------------
                        if fb_data = x"11" then                 -- slang
                            red_r   <= x"F"; 
                            green_r <= x"F"; 
                            blue_r  <= x"F";
                        elsif fb_data = x"EE" then              -- appel
                            red_r   <= x"F"; 
                            green_r <= x"0"; 
                            blue_r  <= x"0";
                        elsif fb_data = x"00" then              -- leeg
                            red_r   <= x"0"; 
                            green_r <= x"0"; 
                            blue_r  <= x"0";
                        elsif fb_data = x"01" then              -- muur
                            if cx_d2 = 0 or cx_d2 = CELL_W-1 or
                               cy_d2 = 0 or cy_d2 = CELL_H-1 then
                                red_r   <= x"3"; 
                                green_r <= x"4"; 
                                blue_r  <= x"C";
                            else
                                red_r   <= x"0"; 
                                green_r <= x"0"; 
                                blue_r  <= x"7";
                            end if;
                        elsif fb_data = x"09" or fb_data = x"0A" then
                            -- Alien: romp met twee ogen en twee pootjes.
                            red_r   <= x"0"; 
                            green_r <= x"0"; 
                            blue_r  <= x"0";
                            if cy_d2 >= 3 and cy_d2 <= 10 and
                               cx_d2 >= 4 and cx_d2 <= 15 then
                                if cy_d2 >= 5 and cy_d2 <= 7 and
                                   ((cx_d2 >= 6 and cx_d2 <= 7) or (cx_d2 >= 12 and cx_d2 <= 13)) then
                                    red_r   <= x"0"; 
                                    green_r <= x"0"; 
                                    blue_r  <= x"0";
                                elsif fb_data = x"09" then
                                    red_r   <= x"3"; 
                                    green_r <= x"E"; 
                                    blue_r  <= x"4";
                                else
                                    red_r   <= x"E"; 
                                    green_r <= x"5"; 
                                    blue_r  <= x"E";
                                end if;
                            elsif cy_d2 >= 11 and cy_d2 <= 13 and ((cx_d2 >= 3 and cx_d2 <= 5) or (cx_d2 >= 14 and cx_d2 <= 16)) then
                                if fb_data = x"09" then
                                    red_r   <= x"3"; 
                                    green_r <= x"E"; 
                                    blue_r  <= x"4";
                                else
                                    red_r   <= x"E"; 
                                    green_r <= x"5"; 
                                    blue_r  <= x"E";
                                end if;
                            end if;
                        elsif fb_data = x"0E" then -- peddel
                            red_r   <= x"0"; 
                            green_r <= x"0"; 
                            blue_r  <= x"0";
                            if cy_d2 >= 5 and cy_d2 <= 10 then
                                red_r   <= x"4"; 
                                green_r <= x"C"; 
                                blue_r  <= x"F";
                            end if;
                        elsif fb_data = x"0F" then -- bal
                            red_r   <= x"0"; 
                            green_r <= x"0"; 
                            blue_r  <= x"0";
                            if cx_d2 >= 6 and cx_d2 <= 13 and cy_d2 >= 4 and cy_d2 <= 11 then
                                red_r   <= x"F"; 
                                green_r <= x"F"; 
                                blue_r  <= x"F";
                            end if;
                        elsif fb_data = x"0B" then -- kanon
                            red_r   <= x"0"; 
                            green_r <= x"0"; 
                            blue_r  <= x"0";
                            if (cy_d2 >= 9 and cx_d2 >= 2 and cx_d2 <= 17) or (cy_d2 >= 4 and cx_d2 >= 8 and cx_d2 <= 11) then
                                red_r   <= x"3"; 
                                green_r <= x"D"; 
                                blue_r  <= x"E";
                            end if;
                        elsif fb_data = x"0C" then -- eigen kogel
                            red_r   <= x"0"; 
                            green_r <= x"0"; 
                            blue_r  <= x"0";
                            if cx_d2 >= 9 and cx_d2 <= 10 then
                                red_r   <= x"F"; 
                                green_r <= x"F"; 
                                blue_r  <= x"C";
                            end if;
                        elsif fb_data = x"0D" then -- bom aliens
                            red_r   <= x"0"; 
                            green_r <= x"0"; 
                            blue_r  <= x"0";
                            if cx_d2 >= 8 and cx_d2 <= 11 and cy_d2 >= 2 and cy_d2 <= 12 then
                                red_r   <= x"F"; 
                                green_r <= x"6"; 
                                blue_r  <= x"1";
                            end if;
                        elsif fb_data = x"80" then -- menubalk
                            red_r   <= x"1"; 
                            green_r <= x"1"; 
                            blue_r  <= x"4";
                        elsif fb_data >= x"02" and fb_data <= x"08" then
                            if cx_d2 <= 1 or cy_d2 <= 1 then
                                red_r   <= x"F"; 
                                green_r <= x"F"; 
                                blue_r  <= x"F";
                            elsif cx_d2 >= CELL_W-2 or cy_d2 >= CELL_H-2 then
                                red_r   <= x"2"; 
                                green_r <= x"2"; 
                                blue_r  <= x"2";
                            else
                                case fb_data is
                                    when x"02" => 
                                        red_r   <=x"1"; 
                                        green_r <=x"D"; 
                                        blue_r  <=x"D";
                                    when x"03" => 
                                        red_r   <=x"E"; 
                                        green_r <=x"E"; 
                                        blue_r  <=x"1";
                                    when x"04" => 
                                        red_r   <=x"C"; 
                                        green_r <=x"2"; 
                                        blue_r  <=x"D";
                                    when x"05" => 
                                        red_r   <=x"1"; 
                                        green_r <=x"D"; 
                                        blue_r  <=x"2";
                                    when x"06" => 
                                        red_r   <=x"E"; 
                                        green_r <=x"2"; 
                                        blue_r  <=x"2";
                                    when x"07" => 
                                        red_r   <=x"2"; 
                                        green_r <=x"4"; 
                                        blue_r  <=x"E";
                                    when others => 
                                        red_r   <=x"E"; 
                                        green_r <=x"8"; 
                                        blue_r  <=x"1";
                                end case;
                            end if;
                        elsif fb_data >= x"40" and fb_data <= x"63" then
                            red_r   <= x"0"; 
                            green_r <= x"0"; 
                            blue_r  <= x"0";
                            if cx_d2 >= 2 and cx_d2 <= 17 and cy_d2 <= 14 then
                                ch   := to_integer(unsigned(fb_data)) - 16#40#;
                                fi   := ch * 5 + cy_d2 / 3;
                                frow := FONT(fi);
                                if frow(3 - (cx_d2 - 2) / 4) = '1' then
                                    red_r   <= x"F"; 
                                    green_r <= x"F"; 
                                    blue_r  <= x"9";
                                end if;
                            end if;
                        else
                            red_r   <= x"0"; 
                            green_r <= x"0"; 
                            blue_r  <= x"4";
                        end if;
                    end if;
                else
                    red_r   <= x"0"; 
                    green_r <= x"0"; 
                    blue_r  <= x"0";
                end if;
            end if;
        end if;
    end process;

    red   <= red_r;
    green <= green_r;
    blue  <= blue_r;
    hsync <= hs_d(2);
    vsync <= vs_d(2);

end Behavioral;
