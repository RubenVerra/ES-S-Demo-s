library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_timing is
    generic(
        H_VISIBLE:  INTEGER := 640;
        H_FRONT:    INTEGER := 16;
        H_SYNC:     INTEGER := 96;
        H_BACK:     INTEGER := 48;

        V_VISIBLE:  INTEGER := 480;
        V_FRONT:    INTEGER := 10;
        V_SYNC:     INTEGER := 2;
        V_BACK:     INTEGER := 33
    );
    port(
        clk:        in  STD_LOGIC;
        ce:         in  STD_LOGIC;                      -- 25 MHz pixelklok
        pixel_x:    out INTEGER range 0 to 1023;
        pixel_y:    out INTEGER range 0 to 1023;
        line_end:   out STD_LOGIC;                      -- laatste pixel van de lijn
        frame_end:  out STD_LOGIC;                      -- laatste pixel van het beeld
        video_on:   out STD_LOGIC;
        hsync:      out STD_LOGIC;
        vsync:      out STD_LOGIC
    );
end vga_timing;

architecture Behavioral of vga_timing is
    constant H_TOTAL: INTEGER := H_VISIBLE + H_FRONT + H_SYNC + H_BACK;  -- 800
    constant V_TOTAL: INTEGER := V_VISIBLE + V_FRONT + V_SYNC + V_BACK;  -- 525

    signal h_count: INTEGER range 0 to 1023 := 0;
    signal v_count: INTEGER range 0 to 1023 := 0;
begin

    pixel_x <= h_count;
    pixel_y <= v_count;

    line_end  <= '1' when h_count = H_TOTAL-1 else '0';
    frame_end <= '1' when (h_count = H_TOTAL-1 and v_count = V_TOTAL-1) else '0';

    process(clk)
    begin
        if rising_edge(clk) then
            if ce = '1' then
                if h_count = H_TOTAL-1 then
                    h_count <= 0;
                    if v_count = V_TOTAL-1 then
                        v_count <= 0;
                    else
                        v_count <= v_count + 1;
                    end if;
                else
                    h_count <= h_count + 1;
                end if;

                if (h_count < H_VISIBLE) and (v_count < V_VISIBLE) then
                    video_on <= '1';
                else
                    video_on <= '0';
                end if;

                if (h_count >= H_VISIBLE + H_FRONT) and (h_count <  H_VISIBLE + H_FRONT + H_SYNC) then
                    hsync <= '0';
                else
                    hsync <= '1';
                end if;

                if (v_count >= V_VISIBLE + V_FRONT) and (v_count <  V_VISIBLE + V_FRONT + V_SYNC) then
                    vsync <= '0';
                else
                    vsync <= '1';
                end if;
            end if;
        end if;
    end process;

end Behavioral;
