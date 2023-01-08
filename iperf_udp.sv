/*WRITE_PKG --->  wordCount>=totalCount ---> recordTime, if Time>threshold  last pkg, other wise not last pkg*/
//timeOut to avoid congestion, so we go to WAIT_RESPONSE state.

module iperfudp (
  input clk,
  input rst,
  input initSeqNum,
  (* anyseq *) input pktArrival,
  input packetGap,
  input receivedResponse,
  output reg [31:0] counter, // comparator counter,
  output wire timeOver,
  output wire lastPkt
);

  reg [31:0] PktTimer;
  reg [31:0] pktCnt;
  reg [3:0] iperfFsmState;
  reg timeOverReg;
  reg lastPktReg;
  reg [7:0] wordCount;
  reg [31:0] seqNumber;
  reg [31:0] cycleCounter;
     
  reg [31:0] waitCounter;
  reg [31:0] pkgHeaderCount;
  reg [31:0] packetGapCounter;
  
  parameter pktNumber = 3,
            senderIPD = 10,
            totalCycles = 995,
            //Other parameters:
            pkgTotalWord = 1000, 
            headerWord = 40,
            timeOverValue = 200,
            WAIT_END = 100,
	    //state
	    IDLE = 0,   //end of a sequence of packets, go back to IDLE
	    CONSTRUCT_HEADER = 1, //end of a packet, go back to CONSTRUCT_HEADER
	    HEADER = 2, 
	    WRITE_PKG = 3, 
	    WAIT_RESPONSE = 4,
	    PKG_GAP = 5;
 
 /*
  initial begin
    assume(rst);
  end
*/

//net connection
assign timeOver = timeOverReg;
assign lastPkt = lastPktReg;

//absolute timer
always @(posedge clk) begin
    if(rst)begin
       cycleCounter <= 0;
    end
    
    else begin
    	cycleCounter<=cycleCounter+1;
    end
end

  
  

//packet counter 
always @(posedge clk) begin
      if(rst)
        pktCnt <= 0;
      else 
         if(pktArrival)
            pktCnt <= pktCnt + 1;
         else
            pktCnt <= pktCnt;
end

//FSM
always @(posedge clk) begin
    if(rst) begin
       seqNumber <= initSeqNum;
       packetGapCounter <= 0;
       waitCounter <= 0; 
    end
    else begin  //!rst
       case(iperfFsmState)
         IDLE: begin    
             timeOverReg <= 0;
             lastPktReg <= 0;
             PktTimer <= cycleCounter;
             wordCount <= 0;
             iperfFsmState <= CONSTRUCT_HEADER;
         end
         
         CONSTRUCT_HEADER: begin
             seqNumber <= seqNumber + 1;
             iperfFsmState <= HEADER;
         end
         
         HEADER: begin
               //header write
         	if(wordCount>headerWord) begin
         	   iperfFsmState <= WRITE_PKG;
         	end    
         	
         	else begin    	
         	   wordCount<=wordCount+1;
         	end
         end
         
         WRITE_PKG: begin
              if (wordCount < pkgTotalWord) begin
		  wordCount <= wordCount + 1;		  
              end
              
              else  //wordCount>=pkgTotalWord, finish transmitting one packet                  
                 //timeOut to avoid congestion, marked as the last packet, so we go to WAIT_RESPONSE state.
		  if(cycleCounter - PktTimer>timeOverValue) begin
                     timeOverReg <= 1;
                     lastPktReg <= 1;
                     if(receivedResponse) begin
			 iperfFsmState <= IDLE;
                     end
                     
                     else begin
                        iperfFsmState <= WAIT_RESPONSE;
                     end
                  end
                     
                  else begin 
                     timeOverReg <= 0;   
                     PktTimer <= cycleCounter - PktTimer;
                  
                    if(packetGap != 0) begin
                       iperfFsmState <= PKG_GAP;
                    end
                    else begin
                       iperfFsmState <= IDLE;
                    end                  
                  end 
              end
         end
         
         WAIT_RESPONSE: begin
             waitCounter <= waitCounter + 1;
             if(waitCounter >= WAIT_END)  begin
                waitCounter <= 0;
                iperfFsmState <= IDLE;
             end
         end
         
         PKG_GAP: begin
         	if(packetGapCounter >= packetGap) begin
         	   packetGapCounter <= 0;
         	   iperfFsmState <= IDLE;
         	end
         	   
         	else begin
         	   packetGapCounter <= packetGapCounter + 1;
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
      
      //packet time simulation
      assume(IPDTimer < rangeMax);      
      if(pktArrival) assume(IPDTimer > rangeMin);
      if(globalTimer == totalCycles )assume(pktCnt == pktNumber);
      assume(pktCnt<=10000);
      //-----//
      
      //Invariant 
       assume(counter <= pktCnt); //-- not automatic
      //assume(counter <= globalTimer / rangeMin); //-- not automatic
      //-----//
      
      
       // a property
       if(globalTimer == totalCycles) assert(counter == 3); 
     
   
     end      
     
     else begin
       assume(rst);
     end
  end
`endif

endmodule
