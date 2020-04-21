module mkrvidor4000_top
(
  // system signals
  input CLK_48MHZ,
  inout SCL,
  inout SDA
);

wire clk_pixel_x5;
wire clk_pixel;
hdmi_pll hdmi_pll(.inclk0(CLK_48MHZ), .c0(clk_pixel), .c1(clk_pixel_x5));


logic [23:0] rgb;
logic [9:0] cx, cy;
hdmi #(.VIDEO_ID_CODE(4), .DVI_OUTPUT(1), .DDRIO(1)) hdmi(.clk_pixel_x10(clk_pixel_x5), .clk_pixel(clk_pixel), .rgb(rgb), .tmds_p(HDMI_TX), .tmds_clock_p(HDMI_CLK), .tmds_n(HDMI_TX_N), .tmds_clock_n(HDMI_CLK_N), .cx(cx), .cy(cy));

logic [7:0] character = 8'd0;
logic [7:0] attribute = 8'd0;
console console(.clk_pixel(clk_pixel), .codepoint(character), .attribute(attribute), .cx(cx), .cy(cy), .rgb(rgb));

logic bus_clear;
logic mode = 1'b0;
logic [7:0] address;
assign address = {7'b1101011, mode};
logic transfer_start = 1'b0;
logic transfer_continues = 1'b0;
logic transfer_ready;
logic interrupt;
logic transaction_complete;
logic nack;
logic address_err;
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
    .address(address),
    .transfer_start(transfer_start),
    .transfer_continues(transfer_continues),
    .transfer_ready(transfer_ready),
    .interrupt(interrupt),
    .transaction_complete(transaction_complete),
    .nack(nack),
    .address_err(address_err),
    .start_err(start_err),
    .arbitration_err(arbitration_err),
    .data_tx(data_tx),
    .data_rx(data_rx)
);

logic state = 1'd0;
always @(posedge CLK_48MHZ)
begin
    // attribute <= {4'd0, state};
    attribute <= {4'd0, 4'd2};
    // character <= {4'h3, state};
    // do some i2c stuff with BQ24195LRGET
    if ((transfer_ready || (transaction_complete && nack)) && state == 1'd0)
    begin
        transfer_start <= 1'b1;
        transfer_continues <= 1'b0;
        mode <= 1'b0;
        data_tx <= 8'h08;
        state <= 1'd1;
        if (transaction_complete)
            character <= {4'h3, data_rx[7:4]};
    end
    else if (state == 1'd1 && interrupt && transaction_complete && !nack)
    begin
        transfer_start <= 1'b1;
        transfer_continues <= 1'b0;
        mode <= 1'b1;
        state <= 1'd0;
    end
end

endmodule
