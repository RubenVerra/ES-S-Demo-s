`timescale 1ns / 1ps
// ---------------------------------------------------------------------------
//  memory_dual_port - 32 kB true dual-port block RAM
//
//  Port A is the 6502 bus, clocked by phi_2.
//  Port B is the frame sender, clocked at 100 MHz.
//
//  Both ports can read and write every cycle, which is what lets the FPGA
//  scan out the screen buffer while the CPU keeps running.
//
//  The RAM is preloaded with the game image at configuration time, so the
//  6502 finds working code the instant it comes out of reset.
// ---------------------------------------------------------------------------

`include "mem_path.vh"

module memory_dual_port(clka,clkb,ena,enb,wea,web,addra,addrb,dia,dib,doa,dob);

    input clka,clkb,ena,enb,wea,web;
    input [14:0] addra,addrb;
    input [7:0] dia,dib;
    output [7:0] doa,dob;
    reg [7:0] ram [0:15'h7fff];   // 32 kB
    reg [7:0] doa,dob;

    initial begin
        $readmemh(`MEM_INIT_FILE, ram);

        // The 6502 reset vector lives at $FFFC/$FFFD, which mirrors down to
        // $7FFC/$7FFD in 32 kB. A valid image points it at the boot code, so
        // an all-zero vector means the file was not read.
        if (ram[15'h7ffc] == 8'h00 && ram[15'h7ffd] == 8'h00) begin
            $display("=====================================================");
            $display(" ERROR: game image not loaded.");
            $display(" $readmemh found nothing at:");
            $display("   %s", `MEM_INIT_FILE);
            $display(" Re-run create_project.tcl to regenerate rtl/mem_path.vh.");
            $display("=====================================================");
        end else begin
            $display("INFO: game image loaded, reset vector = $%02h%02h",
                     ram[15'h7ffd], ram[15'h7ffc]);
        end
    end

    always @(posedge clka)
    begin
        if (ena)
            begin
                if (wea)
                    ram[addra] <= dia;
                doa <= ram[addra];
        end
    end

    always @(posedge clkb)
    begin
        if (enb)
            begin
                if (web)
                    ram[addrb] <= dib;
                dob <= ram[addrb];
        end
    end

endmodule
