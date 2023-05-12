// When the close timer receives a session close signal, it will hold the program for a period of time before closing the session.
module closeTimer (
  input clk,
  input rst,
  input [31:0] interval,
  input [2:0] sessionID,
  output reg pktOut // send packet out
);

  reg [31:0] intervalReg;
  reg closeActive [0:2];
  reg [31:0] globalTimer;
  reg [1:0] state;
  reg [2:0] sessionIDReg;
  reg [31:0] closeSession;
  
  parameter minInterval = 30,
            maxInterval = minInterval*2,
            totalCycles = minInterval*3+5;



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
       pktOut <= 1;
    end   
    else begin
    	if(closeActive[0] && closeActive[1] && closeActive[2] ) pktOut <= 0;
    	else pktOut<= 1;
    end
end
  
 
always @(posedge clk) begin
    if(rst) begin
      closeActive[0]<=0;
      closeActive[1]<=0;
      closeActive[2]<=0;
      closeSession <= 0;       
      intervalReg <= 0;
      state <= 0;     
    end
    else begin  //!rst
      case(state)
      0: begin       
        if(~closeActive[sessionID]) begin
           if(interval<minInterval)intervalReg <= minInterval;
           else intervalReg <= interval;
           sessionIDReg <= sessionID;
           state <= 1;
        end       
      end
    
    
      1: begin         
            if(intervalReg == 0) begin
              closeActive[sessionIDReg] <= 1;
              closeSession <= closeSession + 1;
              state <= 0;
            end
            
            else begin
              intervalReg <= intervalReg - 1;
            end
            
      end
      endcase    
    end
end


`ifdef FORMAL
  always @(posedge clk) begin   
     if(!$initstate) begin
      assume(rst == 0);
      
      //Constraints
      assume(sessionID<=2);   
      //assume(interval>=minInterval);
      //assume(interval<=maxInterval);   
      
      //-----//
      
      //Invariant 
      assume(closeSession>=closeActive[0] && closeSession>=closeActive[1] && closeSession>=closeActive[2]);
      //assume(closeSession<=closeActive[0]+closeActive[1]+closeActive[2]);
      //-----//
      
      // a timing property
      if(globalTimer == totalCycles) assert(closeSession < 3); 
     end      
     
     else begin
       assume(rst);
     end
  end
`endif

endmodule
