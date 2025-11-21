module emu (
    input  wire         CLK_50M,
    input  wire         HPS_BUS_CLK,
    input  wire  [31:0] HPS_ADDR,
    input  wire  [31:0] HPS_DATA_IN,
    output wire  [31:0] HPS_DATA_OUT,
    input  wire         HPS_RW,
    input  wire         HPS_CS,
    output wire         SDRAM_CLK,
    output wire         SDRAM_CKE,
    output wire  [12:0] SDRAM_A,
    output wire   [1:0] SDRAM_BA,
    output wire  [15:0] SDRAM_DQ,
    output wire         SDRAM_DQMH,
    output wire         SDRAM_DQML,
    output wire         SDRAM_nRAS,
    output wire         SDRAM_nCAS,
    output wire         SDRAM_nWE,
    output wire         SDRAM_nCS,
    output wire   [7:0] VGA_R,
    output wire   [7:0] VGA_G,
    output wire   [7:0] VGA_B,
    output wire         VGA_HS,
    output wire         VGA_VS,
    output wire         VGA_DE,
    output wire         VGA_CLK,
    output wire  [15:0] AUDIO_L,
    output wire  [15:0] AUDIO_R,
    output wire         AUDIO_MIX,
    input  wire         RESET,
    output wire         LED_USER,
    output wire         LED_DISK,
    output wire         LED_POWER,
    input  wire  [31:0] joystick_0,
    input  wire  [31:0] joystick_1,
    input  wire  [63:0] status
);

    // ========================================================================
    // 1. Clock Generation
    // ========================================================================
    wire clk_sys; 
    wire clk_vid; 
    wire clk_ram; 
    wire locked;

    pll sys_pll_inst (
        .refclk(CLK_50M),
        .rst(0),
        .outclk_0(clk_sys), 
        .locked(locked)
    );
    assign clk_ram = clk_sys; 
    assign clk_vid = clk_sys; // 20MHz for now (Approx 48Hz refresh on 640x480)

    // ========================================================================
    // 2. System Reset
    // ========================================================================
    reg [7:0] reset_cnt = 0;
    wire sys_reset = (reset_cnt != 8'hFF) || !locked || RESET;
    always @(posedge clk_sys) begin
        if(sys_reset && !RESET) reset_cnt <= reset_cnt + 1;
        else if(RESET) reset_cnt <= 0;
    end

    // ========================================================================
    // 3. Input Subsystem
    // ========================================================================
    wire [31:0] input_data;
    
    gamepad_input input_inst (
        .clk(clk_sys),
        .reset(sys_reset),
        .joy_0(joystick_0),
        .joy_1(joystick_1),
        .addr_match(1'b1), 
        .read_stb(1'b1),
        .data_out(input_data)
    );

    // ========================================================================
    // 4. SDRAM Controller (Keep Alive)
    // ========================================================================
    wire [31:0] ram_dout;
    sdram_controller sdram_inst (
        .clk_sys(clk_sys),
        .SDRAM_A(SDRAM_A), .SDRAM_BA(SDRAM_BA), .SDRAM_DQ(SDRAM_DQ),
        .SDRAM_nRAS(SDRAM_nRAS), .SDRAM_nCAS(SDRAM_nCAS), .SDRAM_nWE(SDRAM_nWE),
        .SDRAM_CKE(SDRAM_CKE), .SDRAM_CLK(SDRAM_CLK), .SDRAM_nCS(SDRAM_nCS),
        .SDRAM_DQML(SDRAM_DQML), .SDRAM_DQMH(SDRAM_DQMH),
        .h_addr(32'd0), .h_din(32'd0), .h_dout(ram_dout), .h_wr(1'b0), .h_req(1'b0), .h_ack(),
        .img_mounted(1'b1), .img_size(32'd64000000), .ioctl_addr(HPS_ADDR),
        .ioctl_dout(HPS_DATA_IN), .ioctl_wr(HPS_RW && HPS_CS)
    );

    // ========================================================================
    // 5. Video Subsystem (VDP-GX)
    // ========================================================================
    wire [7:0] vdp_r, vdp_g, vdp_b;
    wire vdp_hs, vdp_vs, vdp_de;
    
    vdp_gx vdp_inst (
        .clk_sys(clk_sys),
        .clk_vid(clk_vid),
        .rst(sys_reset),
        
        // Feed controller data directly to video for visual testing
        .joy_data(input_data), 
        
        .r(vdp_r), .g(vdp_g), .b(vdp_b),
        .hs(vdp_hs), .vs(vdp_vs), .de(vdp_de),
        .irq_vblank()
    );

    // Output Assignment
    assign VGA_R   = vdp_r;
    assign VGA_G   = vdp_g;
    assign VGA_B   = vdp_b;
    assign VGA_HS  = vdp_hs;
    assign VGA_VS  = vdp_vs;
    assign VGA_DE  = vdp_de;
    assign VGA_CLK = clk_vid;

    // ========================================================================
    // 6. Audio / LED Stubs
    // ========================================================================
    assign AUDIO_L   = 16'd0;
    assign AUDIO_R   = 16'd0;
    assign AUDIO_MIX = 0;
    
    assign LED_USER  = !input_data[0]; // Light LED when "Up" is pressed
    assign LED_DISK  = 0;
    assign LED_POWER = 1;
    assign HPS_DATA_OUT = 32'd0;

endmodule
