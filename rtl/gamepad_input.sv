module gamepad_input (
    input  wire        clk,
    input  wire        reset,
    
    // Inputs from MiSTer Framework
    input  wire [31:0] joy_0,      // Player 1
    input  wire [31:0] joy_1,      // Player 2
    
    // CPU Interface (Memory Mapped)
    input  wire        addr_match, // CPU is addressing 0x1002xxxx
    input  wire        read_stb,   // CPU requesting read
    output reg  [31:0] data_out    // Data back to CPU
);

    // ========================================================================
    // PS1 Digital Controller Layout Mapping
    // ========================================================================
    // MiSTer Default Map: 
    // Bit 0: R, 1: L, 2: D, 3: U, 4: Start, 5: Select, 6: B, 7: A, 8: Y, 9: X, 10: L, 11: R, 12: L2, 13: R2
    
    // Target "Cylon-X" Register Map (16-bit per player):
    // [0] Up      [1] Down    [2] Left    [3] Right
    // [4] Triangle[5] Circle  [6] Cross   [7] Square
    // [8] Select  [9] Start   [10] L1     [11] R1
    // [12] L2     [13] R2     [15:14] Reserved
    
    reg [15:0] p1_state;
    reg [15:0] p2_state;

    always @(posedge clk) begin
        if (reset) begin
            p1_state <= 16'h0000;
            p2_state <= 16'h0000;
        end else begin
            // Mapping Logic (MiSTer -> PS1 Standard)
            // Note: MiSTer joystick bits are usually active HIGH.
            
            // Player 1
            p1_state[0]  <= joy_0[3];  // Up
            p1_state[1]  <= joy_0[2];  // Down
            p1_state[2]  <= joy_0[1];  // Left
            p1_state[3]  <= joy_0[0];  // Right
            
            p1_state[4]  <= joy_0[9];  // X (SNES) -> Triangle
            p1_state[5]  <= joy_0[7];  // A (SNES) -> Circle
            p1_state[6]  <= joy_0[6];  // B (SNES) -> Cross
            p1_state[7]  <= joy_0[8];  // Y (SNES) -> Square
            
            p1_state[8]  <= joy_0[5];  // Select
            p1_state[9]  <= joy_0[4];  // Start
            
            p1_state[10] <= joy_0[10]; // L1
            p1_state[11] <= joy_0[11]; // R1
            p1_state[12] <= joy_0[12]; // L2
            p1_state[13] <= joy_0[13]; // R2
            
            // Player 2 (Repeat mapping for joy_1)
            p2_state[0]  <= joy_1[3]; 
            p2_state[1]  <= joy_1[2];
            p2_state[2]  <= joy_1[1];
            p2_state[3]  <= joy_1[0];
            p2_state[4]  <= joy_1[9];
            p2_state[5]  <= joy_1[7];
            p2_state[6]  <= joy_1[6];
            p2_state[7]  <= joy_1[8];
            p2_state[8]  <= joy_1[5];
            p2_state[9]  <= joy_1[4];
            p2_state[10] <= joy_1[10];
            p2_state[11] <= joy_1[11];
            p2_state[12] <= joy_1[12];
            p2_state[13] <= joy_1[13];
        end
    end

    // ========================================================================
    // Bus Read Logic
    // ========================================================================
    always @(posedge clk) begin
        if (addr_match && read_stb) begin
            // Pack both 16-bit controllers into one 32-bit read
            data_out <= {p2_state, p1_state};
        end else begin
            data_out <= 32'd0;
        end
    end

endmodule