/*

General Description:

Fluorescence activated droplet sorting (FADS) module for the RedPitaya.
This module reads a fluorescence signal from the fast inputs and
triggers a waveform on the arbitrary signal generator (ASG) to be amplified
by an external high voltage amplifier to sort fluorescent droplets.

*/

module red_pitaya_fads #(
    parameter RSZ = 14, // RAM size: 2^RSZ,
    parameter DWT = 14, // data width thresholds
    parameter MEM = 32  // data width RAM
//    parameter signed low_threshold  = 14'b00000000001111,
//    parameter signed high_threshold = 14'b00000011111111
)(
    // ADC
    input                   adc_clk_i       ,   // ADC clock
    input                   adc_rstn_i      ,   // ADC reset - active low
    input signed [14-1: 0]  adc_a_i         ,   // ADC data CHA
//    input       [ 14-1: 0]  adc_b_i         ,   // ADC data CHB

    output reg              sort_trig       ,   // Sorting trigger

    // System bus
    input      [ 32-1: 0] sys_addr      ,  // bus address
    input      [ 32-1: 0] sys_wdata     ,  // bus write data
    input      [  4-1: 0] sys_sel       ,  // bus write byte select
    input                 sys_wen       ,  // bus write enable
    input                 sys_ren       ,  // bus read enable
    output reg [ 32-1: 0] sys_rdata     ,  // bus read data
    output reg            sys_err       ,  // bus error indicator
    output reg            sys_ack          // bus acknowledge signal
);

// Registers for thresholds
// need to be signed for proper comparison with negative voltages
reg signed [DWT -1:0]droplet_threshold;
reg signed [DWT -1:0]sorting_threshold;
reg signed [DWT -1:0]high_threshold;
//reg [MEM -1:0]width_threshold;

// Registers for droplet counters;
reg [MEM -1:0]droplets = 32'd0;

always @(posedge adc_clk_i) begin
    if ((adc_a_i > sorting_threshold) && (adc_a_i < high_threshold))
    begin
        sort_trig <= 1;
        droplets <= droplets + 32'd1;
    end else begin
        sort_trig <= 0;
    end
end

// System bus
// setting up necessary wires
wire sys_en;
assign sys_en = sys_wen | sys_ren;

// Reading from system bus
always @(posedge adc_clk_i)
    // Necessary handling of reset signal
    if (adc_rstn_i == 1'b0) begin
        // resetting to default values
        sorting_threshold   <= 14'b00000000001111;
        high_threshold      <= 14'b00000011111111;
//        droplets            <= 32'd0;
    end else if (sys_wen) begin
        if (sys_addr[19:0]==20'h00000)   sorting_threshold      <= sys_wdata[DWT-1:0];
        if (sys_addr[19:0]==20'h00004)   high_threshold         <= sys_wdata[DWT-1:0];
//        if (sys_addr[19:0]==20'h00008)   droplets               <= sys_wdata[MEM-1:0];
    end

// Writing to system bus
always @(posedge adc_clk_i)
    // Necessary handling of reset signal
    if (adc_rstn_i == 1'b0) begin
        sys_err <= 1'b0;
        sys_ack <= 1'b0;
    end else begin
        sys_err <= 1'b0;
        casez (sys_addr[19:0])
        //   Address  |       handling bus signals        | creating 32 bit wide word containing the data
            20'h00000: begin sys_ack <= sys_en;  sys_rdata <= {{32- DWT{1'b0}}, sorting_threshold}  ; end
            20'h00004: begin sys_ack <= sys_en;  sys_rdata <= {{32- DWT{1'b0}}, high_threshold}     ; end
            20'h00008: begin sys_ack <= sys_en;  sys_rdata <= {{32- MEM{1'b0}}, droplets}           ; end
            default:   begin sys_ack <= sys_en;  sys_rdata <= 32'h0                                 ; end
        endcase
    end

endmodule
