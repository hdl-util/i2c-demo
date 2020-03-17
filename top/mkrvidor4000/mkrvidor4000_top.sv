module mkrvidor4000_top
(
  // system signals
  input CLK_48MHZ,
  input RESETn,
  input SAM_INT_IN,
  output SAM_INT_OUT,
  
  // SDRAM
  output SDRAM_CLK,
  output [11:0] SDRAM_ADDR,
  output [1:0] SDRAM_BA,
  output SDRAM_CASn,
  output SDRAM_CKE,
  output SDRAM_CSn,
  inout [15:0] SDRAM_DQ,
  output [1:0] SDRAM_DQM,
  output SDRAM_RASn,
  output SDRAM_WEn,

  // SAM D21 PINS
  inout MKR_AREF,
  inout [6:0] MKR_A,
  inout [14:0] MKR_D,
  
  // Mini PCIe
  inout PEX_RST,
  inout PEX_PIN6,
  inout PEX_PIN8,
  inout PEX_PIN10,
  input PEX_PIN11,
  inout PEX_PIN12,
  input PEX_PIN13,
  inout PEX_PIN14,
  inout PEX_PIN16,
  inout PEX_PIN20,
  input PEX_PIN23,
  input PEX_PIN25,
  inout PEX_PIN28,
  inout PEX_PIN30,
  input PEX_PIN31,
  inout PEX_PIN32,
  input PEX_PIN33,
  inout PEX_PIN42,
  inout PEX_PIN44,
  inout PEX_PIN45,
  inout PEX_PIN46,
  inout PEX_PIN47,
  inout PEX_PIN48,
  inout PEX_PIN49,
  inout PEX_PIN51,

  // NINA interface
  inout WM_PIO1,
  inout WM_PIO2,
  inout WM_PIO3,
  inout WM_PIO4,
  inout WM_PIO5,
  inout WM_PIO7,
  inout WM_PIO8,
  inout WM_PIO18,
  inout WM_PIO20,
  inout WM_PIO21,
  inout WM_PIO27,
  inout WM_PIO28,
  inout WM_PIO29,
  inout WM_PIO31,
  input WM_PIO32,
  inout WM_PIO34,
  inout WM_PIO35,
  inout WM_PIO36,
  input WM_TX,
  inout WM_RX,
  inout WM_RESET,

  // HDMI output
  output [2:0] HDMI_TX,
  output [2:0] HDMI_TX_N,
  output HDMI_CLK,
  output HDMI_CLK_N,
  inout HDMI_SDA,
  inout HDMI_SCL,
  
  input HDMI_HPD,
  
  // MIPI input
  input [1:0] MIPI_D,
  input MIPI_CLK,
  inout MIPI_SDA,
  inout MIPI_SCL,
  inout [1:0] MIPI_GP,

  // Q-SPI Flash interface
  output FLASH_SCK,
  output FLASH_CS,
  inout FLASH_MOSI,
  inout FLASH_MISO,
  inout FLASH_HOLD,
  inout FLASH_WP,

  inout SCL,
  inout SDA

);

// signal declaration
wire OSC_CLK;

wire [31:0] JTAG_ADDRESS, JTAG_READ_DATA, JTAG_WRITE_DATA, DPRAM_READ_DATA;
wire JTAG_READ, JTAG_WRITE, JTAG_WAIT_REQUEST, JTAG_READ_DATAVALID;
wire [4:0] JTAG_BURST_COUNT;
wire DPRAM_CS;

wire [7:0] DVI_RED,DVI_GRN,DVI_BLU;
wire DVI_HS, DVI_VS, DVI_DE;

wire MEM_CLK;
wire FLASH_CLK;

// internal oscillator
cyclone10lp_oscillator osc (
    .clkout(OSC_CLK),
    .oscena(1'b1)
);

mem_pll mem_pll (
    .inclk0(CLK_48MHZ),
    .c0(MEM_CLK),
    .c1(SDRAM_CLK),
    .c2(FLASH_CLK)
);

wire clk_pixel_x5;
wire clk_pixel;
hdmi_pll hdmi_pll(.inclk0(CLK_48MHZ), .c0(clk_pixel), .c1(clk_pixel_x5));


logic [23:0] rgb;
logic [9:0] cx, cy;
hdmi #(.VIDEO_ID_CODE(4), .DVI_OUTPUT(1), .DDRIO(1)) hdmi(.clk_pixel_x10(clk_pixel_x5), .clk_pixel(clk_pixel), .rgb(rgb), .tmds_p(HDMI_TX), .tmds_clock_p(HDMI_CLK), .tmds_n(HDMI_TX_N), .tmds_clock_n(HDMI_CLK_N), .cx(cx), .cy(cy));

logic [7:0] character = 8'd0;
logic [7:0] attribute = 8'd0;
console console(.clk_pixel(clk_pixel), .character(character), .attribute(attribute), .cx(cx), .cy(cy), .rgb(rgb));

logic bus_clear;
logic mode = 1'b0;
logic transfer_start = 1'b0;
logic transfer_continues = 1'b0;
logic transfer_ready;
logic interrupt;
logic transaction_complete;
logic nack;
logic start_err;
logic arbitration_err;
logic [7:0] data_tx = 8'd0;
logic [7:0] data_rx;

i2c_master #(
    .INPUT_CLK_RATE(48000000),
    .TARGET_SCL_RATE(100000),
    .CLOCK_STRETCHING(1),
    .MULTI_MASTER(0),
    .SLOWEST_DEVICE_RATE(100),
    .FORCE_PUSH_PULL(0)
) i2c_master (
    .scl(SCL),
    .clk_in(CLK_48MHZ),
    .bus_clear(bus_clear),
    .sda(SDA),
    .mode(mode),
    .transfer_start(transfer_start),
    .transfer_continues(transfer_continues),
    .transfer_ready(transfer_ready),
    .interrupt(interrupt),
    .transaction_complete(transaction_complete),
    .nack(nack),
    .start_err(start_err),
    .arbitration_err(arbitration_err),
    .data_tx(data_tx),
    .data_rx(data_rx)
);

logic [3:0] state = 4'd0;
always @(posedge CLK_48MHZ)
begin
    // attribute <= {4'd0, state};
    attribute <= {4'd0, 4'd2};
    // character <= {4'h3, state};
    // do some i2c stuff with BQ24195LRGET
    if (transfer_ready && state == 4'd0)
    begin
        transfer_start <= 1'b1;
        transfer_continues <= 1'b1;
        mode <= 1'b0;
        data_tx <= {7'b1010101, 1'b1};
        state <= state + 4'd1;
    end
    else if (state == 4'd1 && interrupt && transaction_complete && !nack)
    begin
        transfer_start <= 1'b0;
        transfer_continues <= 1'b0;
        mode <= 1'b1;
        state <= state + 4'd1;
    end
    else if (state == 4'd2 && interrupt && transaction_complete && nack)
    begin
        character <= data_rx;
        state <= 4'd0;
    end
    // else if (state == 4'd1 && interrupt && transaction_complete && !nack)
    // begin
    //     transfer_start <= 1'b0;
    //     transfer_continues <= 1'b0;
    //     mode <= 1'b0;
    //     data_tx <= i2c_out;
    //     state <= 4'd0;
    // end
    // else if (state == 4'd2 && interrupt && transaction_complete && !nack)
    // begin
    //     transfer_start <= 1'b1;
    //     transfer_continues <= 1'b1;
    //     mode <= 1'b0;
    //     data_tx <= {7'b1010101, 1'b1};
    //     state <= 4'd3;
    // end
    // else if (state == 4'd3 && interrupt && transaction_complete && !nack)
    // begin
    //     transfer_start <= 1'b0;
    //     transfer_continues <= 1'b0;
    //     mode <= 1'b1;
    //     state <= 4'd4;
    // end
    // else if (state == 4'd4 && interrupt && transaction_complete && nack)
    // begin
    //     character <= {4'h3, data_rx[7:4]};
    //     state <= 4'd0;
    // end
end

endmodule
