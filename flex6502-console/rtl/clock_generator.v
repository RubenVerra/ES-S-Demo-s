`timescale 1ns / 1ps

module clock_generator
    #(parameter DIVISOR_1  = 28'd100,
      parameter phase_diff = 28'd2
    )
    (input             clock_master_100MHz,
     input      [17:0] DIVISOR_2,
     input             clock_enable,
     output reg        phi_1,
     output reg        phi_2
    );

    reg [17:0] div2_r   = 18'd200;
    reg [27:0] prod_r   = DIVISOR_1 * 28'd200;
    reg [27:0] period_r = DIVISOR_1 * 28'd200;
    reg [27:0] half_r   = (DIVISOR_1 * 28'd200) / 2;
    reg [27:0] phase_r  = (DIVISOR_1 * 28'd200) / phase_diff;

    always @(posedge clock_master_100MHz) begin
        div2_r   <= DIVISOR_2;
        prod_r   <= DIVISOR_1 * div2_r;
        period_r <= prod_r;
        half_r   <= prod_r >> 1;
        phase_r  <= prod_r / phase_diff;
    end

    reg [27:0] counter = 28'd0;

    initial begin
        phi_1 = 1'b0;
        phi_2 = 1'b0;
    end

    always @(posedge clock_master_100MHz) begin
        if (clock_enable) begin
            if (counter >= period_r - 28'd1) counter <= 28'd0;
            else                             counter <= counter + 28'd1;

            phi_2 <= (counter < half_r);

            if (phase_diff == 28'd1)
                phi_1 <= (counter < half_r);
            else
                phi_1 <= (counter >= phase_r) && (counter < half_r + phase_r);
        end
    end

endmodule
