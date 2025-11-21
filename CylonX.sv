module emu (
    // Master Clock
    input  wire         CLK_50M,

    // HPS Interface (Control & ROM Loading)
    input  wire         HPS_BUS_CLK,
    input  wire  [31:0] HPS_ADDR,
    input  wire  [31:0] HPS_DATA_IN,
    output wire  [31:0] HPS_DATA_OUT,
    input  wire         HPS_RW,
    input  wire         HPS_CS,

    // SDRAM Interface (External 64MB Module) - RESTORED
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

    // Video Output
    output wire   [7:0] VGA_R,
    output wire   [7:0] VGA_G,
    output wire   [7:0] VGA_B,
    output wire         VGA_HS,
    output wire         VGA_VS,
    output wire         VGA_DE,
    output wire         VGA_CLK,

    // Audio Output
    output wire  [15:0] AUDIO_L,
    output wire  [15:0] AUDIO_R,
    output wire         AUDIO_MIX,
    
    // Framework Signals
    input  wire         RESET,
    output wire         LED_USER,
    output wire         LED_DISK,
    output wire         LED_POWER,
    
    // Input Devices (From Framework)
    input  wire  [31:0] joystick_0,
    input  wire  [31:0] joystick_1,
    input  wire  [63:0] status
);

    // ========================================================================
    // 1. Clock Generation
    // ========================================================================
    wire clk_sys; // 20 MHz (Temporary, Spec targets 100MHz later)
    wire clk_vid; // Pixel Clock
    wire clk_ram; // SDRAM Clock
    wire locked;

    // Use the existing PLL wrapper
    pll sys_pll_inst (
        .refclk(CLK_50M),
        .rst(0),
        .outclk_0(clk_sys), 
        // Note: For now we use clk_sys for SDRAM too until PLL is updated
        // In full design, we need specific phase-shifted clocks.
        .locked(locked)
    );
    assign clk_ram = clk_sys; 
    assign clk_vid = clk_sys; // Temp

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
    // 3. Component: Input Subsystem (PS1 Controller Mapper)
    // ========================================================================
    wire [31:0] input_data;
    
    // Maps joystick_0/1 to the 0x1002xxxx memory region
    gamepad_input input_inst (
        .clk(clk_sys),
        .reset(sys_reset),
        .joy_0(joystick_0),
        .joy_1(joystick_1),
        // CPU isn't here yet, so we hardcode 'read' for testing
        .addr_match(1'b1), 
        .read_stb(1'b1),
        .data_out(input_data)
    );

    // ========================================================================
    // 4. Component: SDRAM Controller
    // ========================================================================
    // Necessary to keep memory refresh active even without a CPU
    wire [31:0] ram_dout;
    
    sdram_controller sdram_inst (
        .clk_sys(clk_sys),
        // Physical Pins
        .SDRAM_A(SDRAM_A), .SDRAM_BA(SDRAM_BA), .SDRAM_DQ(SDRAM_DQ),
        .SDRAM_nRAS(SDRAM_nRAS), .SDRAM_nCAS(SDRAM_nCAS), .SDRAM_nWE(SDRAM_nWE),
        .SDRAM_CKE(SDRAM_CKE), .SDRAM_CLK(SDRAM_CLK), .SDRAM_nCS(SDRAM_nCS),
        .SDRAM_DQML(SDRAM_DQML), .SDRAM_DQMH(SDRAM_DQMH),
        
        // Host Port (Stubbed for now)
        .h_addr(32'd0),
        .h_din(32'd0),
        .h_dout(ram_dout),
        .h_wr(1'b0),
        .h_req(1'b0),
        .h_ack(),
        
        // HPS Port (ROM Loading)
        .img_mounted(1'b1), 
        .img_size(32'd64000000), // 64MB
        .ioctl_addr(HPS_ADDR),
        .ioctl_dout(HPS_DATA_IN),
        .ioctl_wr(HPS_RW && HPS_CS)
    );

    // ========================================================================
    // 5. Video / Audio Stubs
    // ========================================================================
    // Default to Black Screen (VGA standard timing generator needed next)
    assign VGA_R   = 8'd0;
    assign VGA_G   = 8'd0;
    assign VGA_B   = 8'd0; //input_data[7:0]; // debug: visualize inputs on blue channel
    assign VGA_HS  = 1'b1;
    assign VGA_VS  = 1'b1;
    assign VGA_DE  = 1'b1;
    assign VGA_CLK = clk_vid;

    assign AUDIO_L   = 16'd0;
    assign AUDIO_R   = 16'd0;
    assign AUDIO_MIX = 0;
    
    assign LED_USER  = !input_data[0]; // Light LED when "Up" is pressed
    assign LED_DISK  = 0;
    assign LED_POWER = 1;
    
    assign HPS_DATA_OUT = 32'd0;

endmodule