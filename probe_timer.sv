//Determine IPDs of packets at different sessions, and also determine the type (small or large size) of packets
module probeTimer (
  input clk,
  input rst,
  input windowSize,
  input setting,
  input active,
  input [31:0] interval,
  input [1:0] sessionID,
  output reg [1:0] pktFlag // send packet out, 1 marks small packets and 3 marks regular packets, 0 marks no packet.
);

  reg [31:0] regPktCnt;   
  reg [31:0] smallPktCnt;
  reg [31:0] totalPktCnt;
  reg [31:0] intervalReg;
  reg [31:0] pktNumberReg;
  reg [31:0] countUp;
  reg windowSizeReg;
  reg activeArray [0:2];
  reg [31:0] globalTimer;
  reg [1:0] state;
  
  parameter totalCycles = 120,
            pktNumber = 4,
            regPktMin = 20,
            regPktMax = 40;



//absolute timer
always @(posedge clk) begin
    if(rst)begin
       globalTimer <= 0;
    end   
    else begin
    	globalTimer <= globalTimer + 1;
    end
end


always@(posedge clk) begin
  if(setting) begin
    activeArray[sessionID] <= active;
  end
end


  
 
always @(posedge clk) begin
    if(rst) begin
      activeArray[0]<=0;
      activeArray[1]<=0;
      activeArray[2]<=0;
      
      regPktCnt <= 0;  
      countUp <= 0; 
      smallPktCnt <= 0;
      totalPktCnt <= 0;
      intervalReg <= 0;
      pktNumberReg <= 0;
      windowSizeReg <= 0;

      pktFlag <= 0;
      state <= 0;
       
    end
    else begin  //!rst
      case(state)
      0: begin  //setting state     
        if(!setting && activeArray[sessionID]) begin
           pktNumberReg <= pktNumber; 
           windowSizeReg <= windowSize;
           intervalReg <= interval;    
           countUp <= 0;   
           state <= 1;
        end       
      end
    
    
      1: begin  //transmission state
         if(pktNumberReg == 0) begin
            state <= 0;
         end
         
         else begin
            if(countUp >= intervalReg) begin
              if(windowSizeReg) begin
                 regPktCnt <= regPktCnt + 1;
                 pktFlag <= 3;
              end
              else begin 
                smallPktCnt <= smallPktCnt + 1;
                pktFlag <= 1;
              end
              pktNumberReg <= pktNumberReg - 1;
              countUp <= 0;
              totalPktCnt <= totalPktCnt + 1;
            end
            
            else begin
              pktFlag <= 0;
              countUp <= countUp + 1;
            end
         end
      end
      endcase  
    end //for else branch    
end


`ifdef FORMAL
  always @(posedge clk) begin   
     if(!$initstate) begin
      assume(rst == 0);
      
      //Constraints
      assume(sessionID<=2);  
      assume(active == 1);
      assume(interval>=regPktMin);
      if(globalTimer == totalCycles)assume(regPktCnt >= pktNumber || smallPktCnt >=pktNumber);
      //-----//
      
      //Invariant 
     //  assume(activeArray[0] <= 1); 
     //  assume(activeArray[1] <= 1);
     //  assume(activeArray[2] <= 1);
     assume(regPktCnt<=totalPktCnt); 
     assume(smallPktCnt<=totalPktCnt); 
     //assume(countUp<=intervalReg);
      //-----//
      
      // a property
       if(globalTimer == totalCycles ) assert(totalPktCnt >= pktNumber); 
     end      
     
     else begin
       assume(rst);
     end
  end
`endif

endmodule
