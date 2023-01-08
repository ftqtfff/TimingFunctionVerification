module rateLimiter (
  input clk,
  input rst,
  input pktStart,
  (* anyseq *) input pktEnd,
  output reg [31:0] startCnt,
  output reg [31:0] endCnt,
  output reg [31:0] validPkt
);

  reg [31:0] globalTimer;
  reg [31:0] pktTime;
  reg [31:0] delay;
  reg [2:0] state;
  reg [31:0] error;
  //Spec * pktNumber + 1 == totalCycles 
  parameter Spec = 50,
            pktNumber = 20,
            totalCycles = 1001;
 
  
  
  //absolute timer
  always @(posedge clk) begin
      if(rst) globalTimer<= 0;
      else globalTimer <= globalTimer + 1;      
  end
  
  always @(posedge clk) begin
      if(rst) begin
        startCnt <= 0;
        endCnt <= 0;
        pktTime <= 0;
        state <= 0;
        delay <= 0;
        error <= 0;
        validPkt <= 0;
      end
      else begin
        case(state)
        0: begin
          if(pktStart == 1) begin
             state <= 1;
             pktTime <= 1;
             startCnt <= startCnt + 1;
          end
        end
        
        1: begin
          if(pktEnd == 1) begin
             endCnt <= endCnt + 1;
             //endCnt <= startCnt;
             if(pktTime<Spec-1) begin
                validPkt <= validPkt + 1;
                delay <= Spec -2 - pktTime;
                state <= 2;
             end
             else if(pktTime == Spec - 1) begin
                 validPkt <= validPkt + 1;
                 state <= 0;
             end
             else begin
                error <= error + 1;
                state <= 0;
             end
          end
          else pktTime <= pktTime + 1;
        end
        
        2: begin
          if(delay == 0) begin
             state <= 0;
          end
          else begin
            delay <= delay - 1;
          end
        end
        endcase 
      end 
  end

`ifdef FORMAL
  always @(posedge clk) begin   
     if(!$initstate) begin
      assume(rst == 0);
      
      //constraints
      if(startCnt<=pktNumber)assume(pktStart == 1); 
      assume(startCnt<=pktNumber + 1);  //set upper bound
      if(globalTimer == totalCycles)assume(endCnt == pktNumber);
      if(globalTimer == totalCycles)assume(error == 0);
      assume(state<=2);
      //-----//
      
      //Invariant 
      assume(delay <= Spec - 3 && pktTime<=Spec-1);
     
      //verify a timing property
      if(globalTimer == totalCycles) assert(startCnt == pktNumber + 1); //#IPD = pktNumber - 1

     end
     else begin
       assume(rst);
     end
  end
`endif
endmodule
