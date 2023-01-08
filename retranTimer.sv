module retranTimer (
  input clk,
  input rst,
  (* anyseq *) input pktArrival,
  output reg [31:0] pktOut // send packet out
);

  reg [31:0] timeout;   
  reg [31:0] newPktCnt;
  reg [31:0] totalPktCnt;
  reg [31:0] RTT;
  reg [31:0] retryCnt;
  reg [31:0] globalTimer;
  reg [3:0] state;
  
  parameter totalCycles = 200,
            //Other parameters:
            basicTime = 15, 
            retryT1 = 1*basicTime,
            retryT2 = 2*basicTime,
            retryT3 = 3*basicTime,
            retryT4 = 4*basicTime,
            retryT5 = 5*basicTime,
            //state
            ready = 0,
            inTransmit = 1;



//absolute timer
always @(posedge clk) begin
    if(rst)begin
       globalTimer <= 0;
    end   
    else begin
    	globalTimer <= globalTimer + 1;
    end
end


always @(posedge clk) begin
    if(rst)begin
       newPktCnt <= 0;
    end   
    else begin
       if(state == ready) newPktCnt<=newPktCnt+1; //not retransmission
    end
end


always @(posedge clk) begin
    if(rst)begin
       totalPktCnt <= 0;
    end   
    else begin
    	if(state == ready || (state == inTransmit && timeout == 0) ) totalPktCnt <= totalPktCnt + 1;
    end
end

  
 
always @(posedge clk) begin
    if(rst) begin
       pktOut <= 0;
       timeout <= retryT1;        
       RTT <= 0;
       retryCnt <= 0;
       state <= ready;       
    end
    else begin  //!rst
         case(state)
         ready: begin    
		pktOut <= 1;
		state <= inTransmit;
		timeout <= retryT1;
		retryCnt <= 0;
		RTT <= 0;
         end
         
         inTransmit: begin  
                RTT <= RTT + 1;              
                if(timeout == 0) begin
                  pktOut <= 1;
                  if(retryCnt < 4)  begin
                     retryCnt <= retryCnt + 1;
                  end
                  
                  case(retryCnt)
                     0: timeout <= retryT2;
                     1: timeout <= retryT3;
                     2: timeout <= retryT4;
                     3: timeout <= retryT5;
                     4: timeout <= retryT5;
                  endcase 
                end
                
                else begin
                     pktOut <= 0;
                     if(pktArrival) begin
                        state <= ready;                        
                     end
                     else begin
                      timeout <= timeout - 1;
                     end
                end          
         end
         default : begin 
         
         end
       endcase
    end
end


`ifdef FORMAL
  always @(posedge clk) begin   
     if(!$initstate) begin
      assume(rst == 0);
      
      //one set 
      /*
      if(globalTimer == totalCycles)assume(retryCnt == 4); //constraints
      assume(timeout<=retryT5);  //invariant
      if(globalTimer == totalCycles)assert(RTT > 10*basicTime); // a timing property
      */
      //-----//
      if(globalTimer == totalCycles)assume(RTT > totalCycles - 10);
      if(globalTimer == totalCycles)assert(timeout < RTT);
      
      //Invariant 
       assume(timeout <= retryT5); //-- not automati
     end      
     
     else begin
       assume(rst);
     end
  end
`endif

endmodule
