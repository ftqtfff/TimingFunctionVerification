// record how many receiving IPDs are larger than or equal to sending IPDs
module bwe (
  input clk,
  input rst,
  (* anyseq *) input pktArrival,
  output reg [31:0] counter // comparator counter
);

  reg [31:0] globalTimer;
  reg [31:0] IPDTimer;
  reg [31:0] pktCnt;
  
  parameter pktNumber = 3,
            senderIPD = 10,
            totalCycles = 162,
            rangeMax = totalCycles / pktNumber,
            rangeMin = senderIPD;
 

//relative timer
  always @(posedge clk) begin
    if(rst || pktArrival) 
      IPDTimer <= 0;
    else
      IPDTimer <= IPDTimer + 1;
  end
  
  
  always @(posedge clk) begin
      if(rst)
        counter <= 0;
      else 
         if (pktArrival && (IPDTimer >= senderIPD) )
            counter <= counter + 1;
         else
            counter <= counter;
  end
  
  //absolute timer
  always @(posedge clk) begin
      if(rst) globalTimer<= 0;
      else globalTimer <= globalTimer + 1;      
  end
  
  always @(posedge clk) begin
      if(rst)
        pktCnt <= 0;
      else 
         if(pktArrival)
            pktCnt <= pktCnt + 1;
         else
            pktCnt <= pktCnt;
  end

`ifdef FORMAL
  always @(posedge clk) begin   
     if(!$initstate) begin
      assume(rst == 0);
      
      //IPDTimer belongs to the range (rangeMin, rangeMax)
      assume(IPDTimer < rangeMax);      
      if(pktArrival) assume(IPDTimer > senderIPD);
      if(globalTimer == totalCycles )assume(pktCnt == pktNumber);
      //-----//
      
      //Invariant 
      assume(counter <= pktCnt); 

      //verify a timing property
      if(globalTimer == totalCycles) assert(counter == 3); 
      
      //verify the invariant
    //  assert(counter <= pktCnt);

     end
     else begin
       assume(rst);
     end
  end
`endif
endmodule
