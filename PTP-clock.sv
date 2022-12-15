/*

Copyright (c) 2015-2019 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`timescale 1ns / 1ps
`default_nettype none

/*
 * PTP clock module
 */
module ptp_clock #
(
    parameter DRIFT_NS = 4'h0,
    parameter DRIFT_RATE = 16'h0005,
    parameter totalCycles = 500,
    parameter timeUnit = 31,
)
(
    input  wire                       clk,
    input  wire                       rst,
    input  wire                       input_ts_96_valid,
    input  wire                input_period_valid,
    input  wire                input_adj_valid,
    input  wire                 input_drift_valid,

    /*
     * Timestamp outputs
     */
    output wire [timeUnit-1:0]  output_ts_96
);


    /*
     * Timestamp inputs for synchronization
     */
    (* anyconst *) reg [timeUnit-5:0] input_ts_96;
    

    /*
     * Period adjustment
     */
    (* anyconst *) reg [timeUnit-5:0] input_period_ns;   
    reg [timeUnit-5:0] period_ns_reg;
    

    /*
     * Offset adjustment
     */
    (* anyconst *) reg [timeUnit-5:0] input_adj_ns;
    (* anyconst *) reg [timeUnit-5:0] input_adj_count;
    reg [timeUnit-5:0] adj_ns_reg;
    reg [timeUnit-5:0] adj_count_reg;
    

    /*
     * Drift adjustment
     */
    (* anyconst *) reg [timeUnit-5:0]  input_drift_ns;
    (* anyconst *) reg [timeUnit-5:0]  input_drift_count;
    reg [timeUnit-5:0] drift_ns_reg;
    reg [timeUnit-5:0] drift_cnt;
    


reg [timeUnit-1:0] outputTime;
assign output_ts_96 = outputTime;  
//---formal verification----//
reg [timeUnit-1:0] globalTimer;


always @(posedge clk) begin
     if(!rst) begin
	    // latch parameters
	    if (input_period_valid) begin
		period_ns_reg <= input_period_ns;
	    end

	    if (input_adj_valid) begin
		adj_ns_reg <= input_adj_ns;
	    end

	    if (input_drift_valid) begin
		drift_ns_reg <= input_drift_ns;
	    end

	    // timestamp increment calculation
	    outputTime <= input_ts_96 + period_ns_reg + ( (drift_cnt==0)? drift_ns_reg : 0) +
		((adj_count_reg == 0) ? adj_ns_reg : 0);

	    // offset adjust counter
	    if (adj_count_reg > 0) begin
		adj_count_reg <= adj_count_reg - 1;
	    end 
	    else begin
		adj_count_reg <= adj_count_reg;
	    end

	    // drift counter
	    if (drift_cnt > 0) begin
	    	drift_cnt <= drift_cnt - 1;       
	    end else begin
		drift_cnt <= 0;   //reset
	    end

    // 96 bit timestamp
    // no increment seconds field, pre-compute both normal increment and overflow values

    end

    else begin  //rst
        period_ns_reg <= 0;
        adj_count_reg <= input_adj_count;
        drift_cnt <= input_drift_count;
        adj_ns_reg <= 0;
        drift_ns_reg <= 0;
        outputTime <= 0;
    end
end


//absolute timer
always @(posedge clk) begin
   if(rst) globalTimer <= 0;
   else globalTimer <= globalTimer + 1;      
end


`ifdef FORMAL
  always @(posedge clk) begin 
     //system configurations//
     assume(input_period_valid);
     assume(input_adj_valid);
     assume(input_drift_valid);
     assume(input_adj_count + input_drift_count == totalCycles );
     /*self-test
     assume(input_start == 0);
     assume(input_ts_96 == 160); 
     assume(input_period == 60); pulseCounter == 3
     */
     if(!$initstate) begin
      assume(rst == 0);
      
      //a timing property
      if( globalTimer < totalCycles ) assert( outputTime <= adj_ns_reg + drift_ns_reg + period_ns_reg + input_ts_96 );
      
     // if( globalTimer == totalCycles )assert(pulseCounter == 2);
      
      //Invariant 
    //  assume(pulseCounter <= input_ts_96 -  input_start ); //-- not automatic
     // assume(pulseCounter <= 10 ); //-- not automatic
      //maxValue of input_period: maxPeriod as a efficient
      //-----//           
     end
     else begin
       assume(rst);
     end
  end
`endif




endmodule

`resetall
