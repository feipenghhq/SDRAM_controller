module altpll_top #(
    parameter CLK_FREQ = 130
) (
    input  logic        clk,
    output              sdram_clk,
    output              sdram_clk_out,
    output logic [2:0]  cfg_cas_latency
);

    // Instantiate different PLL to test different clock
    generate
    if (CLK_FREQ == 25) begin: clk25
        altpll_25 u_pll(
            .inclk0 (clk),
            .c0     (sdram_clk),
            .c1     (sdram_clk_out));
        assign cfg_cas_latency  = 3'd2;
    end

    if (CLK_FREQ == 50) begin: clk50
        altpll_50 u_pll(
            .inclk0 (clk),
            .c0     (sdram_clk),
            .c1     (sdram_clk_out));
        assign cfg_cas_latency  = 3'd2;
    end

    if (CLK_FREQ == 100) begin: clk100
        altpll_100 u_pll(
            .inclk0 (clk),
            .c0     (sdram_clk),
            .c1     (sdram_clk_out));
        assign cfg_cas_latency  = 3'd3;
    end

    if (CLK_FREQ == 130) begin: clk130 // CLK FREQ is actual 130
        altpll_130 u_pll(
            .inclk0 (clk),
            .c0     (sdram_clk),
            .c1     (sdram_clk_out));
        assign cfg_cas_latency  = 3'd3;
    end

endgenerate

endmodule
