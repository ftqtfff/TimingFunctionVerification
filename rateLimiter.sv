module rateLimiter (
  input clk,
  input rst,
  input pktStart,
  input pktEnd,
  output reg [31:0] startCnt,
  output reg [31:0] endCnt
);

  reg [31:0] globalTimer;
  reg [31:0] pktTime;
  reg [31:0] delay;
  reg [2:0] state;
  reg [31:0] error;
  
  parameter Spec = 10,
            totalCycles = 162;
 
  
  
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
                delay <= Spec -2 - pktTime;
                state <= 2;
             end
             else begin
               state <= 0;
               if(pktTime>Spec-1) error <= error + 1;
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
      
      //IPDTimer belongs to the range (rangeMin, rangeMax)
      assume(pktStart == 1);      
     // assume(pktTime<Spec-1);
      assume(state<=2);
      //-----//
      
      //Invariant 
     // assume(counter <= pktCnt); 

      //verify a timing property
      //if(globalTimer == totalCycles) assert(endCnt == 16 || endCnt == 17); 
      
      //verify the invariant
      //assume(endCnt<100);
      //assert(endCnt>=error);
      assume(startCnt<1000);
      assume(endCnt<1000);
     // if(Spec-2-$past(pktTime)>$past(delay))assert(delay<=Spec-2-$past(pktTime));
     // else assert(delay<=$past(delay));
     
     //assert(startCnt>=endCnt);
     assert(startCnt>=error);
     //assert(endCnt>=error);

     end
     else begin
       assume(rst);
     end
  end
`endif
endmodule
