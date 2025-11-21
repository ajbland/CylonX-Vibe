module vdp_gx (
    input  wire        clk_sys,    // Logic Clock
    input  wire        clk_vid,    // Pixel Clock
    input  wire        rst,

    // CPU / System Interface
    input  wire [31:0] joy_data,   // Debug: Show controller state on screen

    // Video Output
    output reg   [7:0] r,
    output reg   [7:0] g,
    output reg   [7:0] b,
    output reg         hs,
    output reg         vs,
    output reg         de,         // Data Enable (Active High area)
    output wire        irq_vblank
);

    // ========================================================================
    // 1. Video Timing Constants (Standard 640x480)
    // ========================================================================
    // Horizontal: Total 800 clocks
    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

    // Vertical: Total 525 lines
    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

    // ========================================================================
    // 2. Counters
    // ========================================================================
    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    always @(posedge clk_vid) begin
        if (rst) begin
            h_cnt <= 0;
            v_cnt <= 0;
        end else begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= 0;
                if (v_cnt == V_TOTAL - 1) begin
                    v_cnt <= 0;
                end else begin
                    v_cnt <= v_cnt + 1;
                end
            end else begin
                h_cnt <= h_cnt + 1;
            end
        end
    end

    // ========================================================================
    // 3. Sync Signal Generation
    // ========================================================================
    // HS is usually Active Low for 640x480
    // VS is usually Active Low for 640x480
    always @(posedge clk_vid) begin
        hs <= !((h_cnt >= H_VISIBLE + H_FRONT) && (h_cnt < H_VISIBLE + H_FRONT + H_SYNC));
        vs <= !((v_cnt >= V_VISIBLE + V_FRONT) && (v_cnt < V_VISIBLE + V_FRONT + V_SYNC));
        
        // Data Enable: High when inside the visible area
        de <= (h_cnt < H_VISIBLE) && (v_cnt < V_VISIBLE);
    end

    // Interrupt Generation (Trigger at start of VBlank)
    assign irq_vblank = (v_cnt == V_VISIBLE) && (h_cnt == 0);

    // ========================================================================
    // 4. Test Pattern Generator (The "Renderer")
    // ========================================================================
    // This simple logic replaces the future Sprite/Tile engines.
    
    // Extract PS1 buttons for visualization
    wire btn_cross  = joy_data[6];  // P1 Cross
    wire btn_circle = joy_data[5];  // P1 Circle
    wire btn_up     = joy_data[0];  // P1 Up
    wire btn_down   = joy_data[1];  // P1 Down

    always @(posedge clk_vid) begin
        if (de) begin
            // Default Background: Dark Grey
            r <= 8'h40;
            g <= 8'h40;
            b <= 8'h40;

            // DRAW: Grid Lines every 64 pixels
            if (h_cnt[5:0] == 0 || v_cnt[5:0] == 0) begin
                r <= 8'h20; g <= 8'h20; b <= 8'h20;
            end

            // DRAW: Color Bars based on inputs
            
            // If "Cross" (Blue button) is held, make screen Blueish
            if (btn_cross) b <= 8'hFF;
            
            // If "Circle" (Red button) is held, make screen Reddish
            if (btn_circle) r <= 8'hFF;

            // DRAW: A moving square controlled by Up/Down
            // (Super simple animation test)
            if (h_cnt > 300 && h_cnt < 340) begin
                if (btn_up   && v_cnt < 240) g <= 8'hFF; // Top half Green
                if (btn_down && v_cnt > 240) g <= 8'hFF; // Bottom half Green
            end
        end else begin
            // Black outside visible area
            r <= 0; g <= 0; b <= 0;
        end
    end

endmodule