//default_nettype none

module screen #(
    parameter STARTUP_WAIT = 32'd10_000_000,  // Power-on delay
    parameter REFRESH_DIVIDER = 27'd9  // 27MHz/30Hz = 900,000 Data changed here
)(
    input clk,           // 27MHz clock
    output io_sclk,      // SPI clock
    output io_sdin,      // SPI data
    output io_cs,        // Chip select
    output io_dc,        // Data/command
    output io_reset,     // Reset
    
    // Frame buffer update interface
    output reg buffer_update_request,  // Pulses high when new frame can be prepared
    input [9:0] buffer_update_addr,    // Address to update (0-1023)
    input [7:0] buffer_update_data,    // Data to write
    input buffer_update_write          // Write strobe
);

    // State machine states
    localparam STATE_INIT_POWER        = 0;
    localparam STATE_LOAD_INIT_CMD     = 1;
    localparam STATE_SEND              = 2;
    localparam STATE_CHECK_FINISHED_INIT = 3;
    localparam STATE_LOAD_DATA         = 4;
    
    // Display control registers
    reg [2:0] state = STATE_INIT_POWER;
    reg [31:0] counter = 0;
    reg dc = 1;
    reg sclk = 1;
    reg sdin = 0;
    reg reset = 1;
    reg cs = 0;
    
    // Data transmission registers
    reg [7:0] dataToSend = 0;
    reg [3:0] bitNumber = 0;
    reg [9:0] pixelCounter = 0;
    
    // Refresh timing
    reg [26:0] refreshCounter = 0;
    wire refreshTrigger = (refreshCounter == REFRESH_DIVIDER - 1);
    
    // Initialization commands (23 commands)
    localparam SETUP_INSTRUCTIONS = 23;
    reg [(SETUP_INSTRUCTIONS*8)-1:0] startupCommands = {
        8'hAE, 8'h81, 8'h7F, 8'hA6, 8'h20, 8'h00, 8'hC8, 
        8'h40, 8'hA1, 8'hA8, 8'h3F, 8'hD3, 8'h00, 8'hD5, 
        8'h80, 8'hD9, 8'h22, 8'hDB, 8'h20, 8'h8D, 8'h14, 
        8'hA4, 8'hAF
    };
    reg [7:0] commandIndex = SETUP_INSTRUCTIONS * 8;
    
    // Screen buffer (128x64 = 1024 bytes)
    (* ram_style = "block" *) reg [7:0] screenBuffer [0:1023];
   // initial $readmemh("image.hex", screenBuffer);
    
    // Output assignments
    assign io_sclk = sclk;
    assign io_sdin = sdin;
    assign io_dc = dc;
    assign io_reset = reset;
    assign io_cs = cs;
    
    // Buffer update handling
    always @(posedge clk) begin
        if (buffer_update_write) begin
            screenBuffer[buffer_update_addr] <= buffer_update_data;
        end
    end
    
    // Refresh timing counter
    always @(posedge clk) begin
        buffer_update_request <= 0;
        if (state >= STATE_LOAD_DATA) begin  // Only after initialization
            if (refreshTrigger) begin
                refreshCounter <= 0;
                buffer_update_request <= 1;
            end else begin
                refreshCounter <= refreshCounter + 1;
            end
        end
    end
    
    // Main state machine
    always @(posedge clk) begin
        case (state)
            STATE_INIT_POWER: begin
                counter <= counter + 1;
                if (counter < STARTUP_WAIT)
                    reset <= 1;
                else if (counter < STARTUP_WAIT * 2)
                    reset <= 0;
                else if (counter < STARTUP_WAIT * 3)
                    reset <= 1;
                else begin
                    state <= STATE_LOAD_INIT_CMD;
                    counter <= 0;
                end
            end
            
            STATE_LOAD_INIT_CMD: begin
                dc <= 0;
                dataToSend <= startupCommands[(commandIndex-1)-:8];
                state <= STATE_SEND;
                bitNumber <= 3'd7;
                cs <= 0;
                commandIndex <= commandIndex - 8;
            end
            
            STATE_SEND: begin
                if (counter == 0) begin
                    sclk <= 0;
                    sdin <= dataToSend[bitNumber];
                    counter <= 1;
                end else begin
                    counter <= 0;
                    sclk <= 1;
                    if (bitNumber == 0)
                        state <= STATE_CHECK_FINISHED_INIT;
                    else
                        bitNumber <= bitNumber - 1;
                end
            end
            
            STATE_CHECK_FINISHED_INIT: begin
                cs <= 1;
                if (commandIndex == 0)
                    state <= STATE_LOAD_DATA;
                else
                    state <= STATE_LOAD_INIT_CMD;
            end
            
            STATE_LOAD_DATA: begin
                if (pixelCounter == 0) begin
                    // Send address commands at start of frame
                    dc <= 0; // Command mode
                    if (bitNumber == 3'd7) begin
                        dataToSend <= 8'h21; // Column address set
                        bitNumber <= 3'd6;
                    end
                    else if (bitNumber == 3'd6) begin
                        dataToSend <= 8'h00; // Start column
                        bitNumber <= 3'd5;
                    end
                    else if (bitNumber == 3'd5) begin
                        dataToSend <= 8'h7F; // End column
                        bitNumber <= 3'd4;
                    end
                    else if (bitNumber == 3'd4) begin
                        dataToSend <= 8'h22; // Page address set
                        bitNumber <= 3'd3;
                    end
                    else if (bitNumber == 3'd3) begin
                        dataToSend <= 8'h00; // Start page
                        bitNumber <= 3'd2;
                    end
                    else if (bitNumber == 3'd2) begin
                        dataToSend <= 8'h07; // End page
                        bitNumber <= 3'd1;
                    end
                    else begin
                        dc <= 1; // Switch to data mode
                        dataToSend <= screenBuffer[pixelCounter];
                        pixelCounter <= pixelCounter + 1;
                        bitNumber <= 3'd7;
                    end
                end
                else begin
                    dc <= 1; // Data mode
                    dataToSend <= screenBuffer[pixelCounter];
                    pixelCounter <= pixelCounter + 1;
                    if (pixelCounter == 10'd1023)
                        pixelCounter <= 0;
                end
                cs <= 0;
                state <= STATE_SEND;
            end
        endcase
    end







// Instantiate frame updater
  frame_updater updater (
    .clk(clk),
    .updateRequest(buffer_update_request),
    .addr(buffer_update_addr),
    .data(buffer_update_data),
    .write(buffer_update_write)
  );














endmodule
