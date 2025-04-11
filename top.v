module top (
  input clk,
  input btn1,
  input btn2,
    output io_sclk,
    output io_sdin,
    output io_cs,
    output io_dc,
    output io_reset
);
  
  // Instantiate screen controller
  screen display (
    .clk(clk),
.io_sclk(io_sclk),
.io_sdin(io_sdin),
.io_cs(io_cs),
.io_dc(io_dc),
.io_reset(io_reset)
  );
  
  
  
endmodule