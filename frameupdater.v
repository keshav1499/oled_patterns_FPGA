/*// Example usage module that implements frame updates
module frame_updater (
  input clk,
  input updateRequest,      // 30Hz update trigger
  output reg [9:0] addr,    // Buffer address to update
  output reg [7:0] data,    // Data to write
  output reg write          // Write strobe
);
  
  // Your custom frame update logic goes here
  // This example just creates a simple moving pattern
  reg [9:0] x_position = 0;
  
  always @(posedge clk) begin
    write <= 0;
    if (updateRequest) begin
      // Update all pixels in the frame
      for (integer y = 0; y < 8; y=y+1) begin
        for (integer x = 0; x < 128; x=x+1) begin
          addr <= y * 128 + x;
          data <= (x == x_position) ? 8'hFF : 8'h00; // Vertical line
          write <= 1;
          @(posedge clk); // Wait one cycle per pixel
          write <= 0;
        end
      end
      
      // Move the line
      x_position <= (x_position == 127) ? 0 : x_position + 1;
    end
  end
endmodule
*/


module frame_updater (
    input clk,
    input updateRequest,
    output reg [9:0] addr,
    output reg [7:0] data,
    output reg write
);
    reg [6:0] x_pos = 0;       // 7 bits for 0-127
    reg [2:0] current_page = 0; // 3 bits for 0-7
    reg [6:0] col_counter = 0;  // 7 bits for 0-127

/*   always @(posedge clk) begin
        write <= 0;
        if (updateRequest) begin
            if (col_counter < 127) begin
                addr <= current_page * 128 + col_counter;
                data <= (col_counter == x_pos) ? 8'hFF : 8'h00;
                write <= 1;
                col_counter <= col_counter + 1;
            end
            else begin
                col_counter <= 0;
                current_page <= (current_page == 7) ? 0 : current_page + 1;              //Sequentail Rain drop patterns
                x_pos <= (x_pos == 127) ? 0 : x_pos + 1;
            end
        end
    end
*/

/*always @(posedge clk) begin
    write <= 0; // Default no write
    if (updateRequest) begin
        // Calculate moving pattern
        addr <= current_page * 128 + col_counter;
        data <= (col_counter == (x_pos + current_page * 16)) ? 8'hFF : 
               ((col_counter == (x_pos + current_page * 16 + 32)) ? 8'hFF : 8'h00);
        write <= 1;
        
        // Update counters
        if (col_counter < 127) begin
            col_counter <= col_counter + 1;
        end                                                                                     //Square drop
        else begin
            col_counter <= 0;
            if (current_page < 7) begin
                current_page <= current_page + 1;
            end
            else begin
                current_page <= 0;
                x_pos <= (x_pos == 127) ? 0 : x_pos + 1;
            end
        end
    end
end


*/


always @(posedge clk) begin
    write <= 0;
    if (updateRequest) begin
        addr <= current_page * 128 + col_counter;
        data <= (col_counter * current_page + x_pos) & 8'h10 
                ? 8'hFF : 8'h00;
        write <= 1;
        
        if (col_counter < 127) col_counter <= col_counter + 1;
        else begin
            col_counter <= 0;
            current_page <= (current_page < 7) ? current_page + 1 : 0;
            x_pos <= x_pos - 1;
        end
    end
end


endmodule


