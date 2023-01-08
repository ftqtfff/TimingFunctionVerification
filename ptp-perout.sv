

// Language: Verilog 2001

/*
 * PTP period out module.  NS is 31-bit
 */
module ptp_perout #   //set period, width, start time of a clock
(
    parameter totalCycles = 595,
    parameter TIME_WIDTH = 30
)
(
    input  wire         clk,
    input  wire         rst,

    /*
     * Timestamp input from PTP clock
     */
    input  wire         input_start_valid,
    input  wire         input_period_valid,  
    input  wire         input_width_valid,

    output wire         output_error,
    output wire         output_pulse
);


(* anyconst *) reg [TIME_WIDTH:0]  input_ts_96;
(* anyconst *) reg [TIME_WIDTH:0]  input_start;
(* anyconst *) reg [TIME_WIDTH:0]  input_period;
(* anyconst *) reg [TIME_WIDTH:0]  input_width;
 

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_UPDATE_RISE_1 = 3'd1,   //update edges
    STATE_UPDATE_RISE_2 = 3'd2,   //check overflow
    STATE_UPDATE_FALL_1 = 3'd3,   //update edges
    STATE_UPDATE_FALL_2 = 3'd4,   //check overflow
    STATE_WAIT_EDGE = 3'd5;

reg [2:0] state_reg = STATE_IDLE, state_next;
reg [30:0] now_ns_reg = 0, now_ns_next;
reg [30:0] next_rise_ns_reg = 0, next_rise_ns_next;
reg [30:0] next_fall_ns_reg = 0, next_fall_ns_next;
reg [30:0] period_ns_reg;
reg [30:0] width_ns_reg;
reg [30:0] ts_96_ns_inc_reg = 0, ts_96_ns_inc_next;

reg output_reg = 1'b0, output_next = 1'b0;
reg output_error_reg = 1'b0, output_error_next;
assign output_pulse = output_reg;
assign output_error = output_error_reg;

reg [10:0] pulseCounter;

//---formal verification----//
reg [30:0] globalTimer;


always @(posedge clk) begin
   if(rst)pulseCounter <= 0;
   else if(output_reg == 1'b0 && output_next == 1'b1)
   pulseCounter <= pulseCounter+1;
   else pulseCounter<=pulseCounter;
end


always @* begin   
    next_rise_ns_next = next_rise_ns_reg;
    next_fall_ns_next = next_fall_ns_reg;
    ts_96_ns_inc_next = ts_96_ns_inc_reg;
    now_ns_next = now_ns_reg + 1;
    output_error_next = 1'b0;   
    state_next = state_reg;

    case (state_reg)
	STATE_IDLE: begin
	    output_next = 1'b0; 	    
	    if(now_ns_reg>input_ts_96) begin
	       output_error_next = 1'b1;
	       state_next = STATE_IDLE;
	    end
	    
	    if (input_start_valid && input_period_valid && input_width_valid) begin
	       next_rise_ns_next = now_ns_reg;
	       state_next = STATE_WAIT_EDGE;
	    end	    

	    else begin
	      state_next = STATE_IDLE;
	    end 	
	end
	STATE_UPDATE_RISE_1: begin
	// set next rise time to next rise time plus period
	ts_96_ns_inc_next = next_rise_ns_reg + period_ns_reg;
	state_next = STATE_UPDATE_RISE_2;
	end
	
	STATE_UPDATE_RISE_2: begin
	next_rise_ns_next = ts_96_ns_inc_reg;
	state_next = STATE_WAIT_EDGE;
	end
	

	STATE_UPDATE_FALL_1: begin
	// set next fall time to next rise time plus width
	ts_96_ns_inc_next = next_rise_ns_reg + width_ns_reg;
	state_next = STATE_UPDATE_FALL_2;
	end
	
	STATE_UPDATE_FALL_2: begin
	next_fall_ns_next = ts_96_ns_inc_reg;
	state_next = STATE_WAIT_EDGE;
	end
	
	STATE_WAIT_EDGE: begin	
	 if(now_ns_reg<=input_ts_96) begin	   
	    if(now_ns_reg>=next_rise_ns_reg && output_reg == 1'b0) begin
	       output_next = 1'b1;
	       state_next = STATE_UPDATE_FALL_1;
	    end
	   
	    else if(now_ns_reg>=next_fall_ns_reg && output_reg == 1'b1) begin
	       output_next = 1'b0;
	       state_next = STATE_UPDATE_RISE_1;
	    end
	   
	    else state_next = STATE_WAIT_EDGE;
	  end
	  
	  else begin
	     output_next = 1'b0;
	  end
	end
   endcase
end

always @(posedge clk) begin
    state_reg <= state_next;
    output_reg <= output_next;
    output_error_reg <= output_error_next;
    next_rise_ns_reg <= next_rise_ns_next;
    next_fall_ns_reg <= next_fall_ns_next;
    ts_96_ns_inc_reg <= ts_96_ns_inc_next;

    if (rst) begin
        state_reg <= STATE_IDLE;   
        output_reg <= 1'b0;
        output_error_reg <= 1'b0;  
        
        if (input_period_valid) begin
           period_ns_reg <= input_period;
        end
        
        else begin
           period_ns_reg <= 0;
        end
        
        if (input_width_valid) begin
           width_ns_reg <= input_width;
        end
        
        else begin
           width_ns_reg <= 0;
        end

        
        if(input_start_valid) begin
           now_ns_reg <= input_start;  
        end
        
        else begin
           now_ns_reg <= 0;
        end
        
        
    end //rst
    
    else begin  //!rst
        now_ns_reg <= now_ns_next;
    end
    
end //always


//absolute timer
always @(posedge clk) begin
   if(rst) globalTimer<= 0;
   else globalTimer <= globalTimer + 1;      
end


`ifdef FORMAL
  always @(posedge clk) begin 
     //system configurations//
     assume(input_start_valid);  
     assume(input_period_valid);
     assume(input_width_valid);
     assume(input_start == 0);
     assume(input_ts_96 > input_start);
     assume(input_ts_96 - input_start < totalCycles);
     assume(input_ts_96 - input_start > input_period);
     assume(input_width < input_period);
     assume(input_width > 4);
     
     /*self-test
     assume(input_start == 0);
     assume(input_ts_96 == 160); 
     assume(input_period == 60); pulseCounter == 3
     */
     if(!$initstate) begin
      assume(rst == 0);
      
      //a timing property
       if( globalTimer == totalCycles ) assert( (pulseCounter + 1) * input_period > (input_ts_96 -  input_start));
     // if( globalTimer == totalCycles )assert(pulseCounter == 2);
      
      //Invariant 
       assume(pulseCounter <= input_ts_96 -  input_start ); //-- not automatic
       //assume(pulseCounter <= 10 ); //-- not automatic
      //maxValue of input_period: maxPeriod as a efficient
      //-----//
      
     
     end

          
     else begin
       assume(rst);
     end
  end
`endif


endmodule













