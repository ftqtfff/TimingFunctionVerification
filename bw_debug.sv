// record the total transmission time and the non-transmission time of probing packets.
// property: total time = transmission time + non-transmission time
module bandwith_reg #
    (
        // Users to add parameters here

        // User parameters ends
        // Do not modify the parameters beyond this line

        // Width of S_AXI data bus
        parameter C_AXIS_DATA_WIDTH             = 512,
        parameter TUSER_WIDTH                   =  10,
        parameter TDEST_WIDTH                   =  1,
        parameter USE_KEEP                      =  0,
        parameter totalCycles                   = 200

        // Width of S_AXI address bus

        )
    (
        // Users to add ports here
        (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 IN_DBG TDATA" *)
        input wire [C_AXIS_DATA_WIDTH-1:0]                  S_AXIS_TDATA,
        (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 IN_DBG TKEEP" *)
        input wire [(C_AXIS_DATA_WIDTH/8)-1:0]              S_AXIS_TKEEP,
        (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 IN_DBG TSTRB" *)
        input wire [(C_AXIS_DATA_WIDTH/8)-1:0]              S_AXIS_TSTRB,
        (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 IN_DBG TVALID" *)
        input wire                                          S_AXIS_TVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 IN_DBG TREADY" *)
        output wire                                         S_AXIS_TREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 IN_DBG TLAST" *)
        input wire                                          S_AXIS_TLAST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 IN_DBG TUSER" *)
        input wire [TUSER_WIDTH-1:0]                        S_AXIS_TUSER,     
        (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 IN_DBG TDEST" *)
        input wire [TDEST_WIDTH-1:0]                        S_AXIS_TDEST,       

        (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 OUT_DBG TDATA" *)
        output wire [C_AXIS_DATA_WIDTH-1:0]                 M_AXIS_TDATA,
        (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 OUT_DBG TSTRB" *)
        output wire [(C_AXIS_DATA_WIDTH/8)-1:0]             M_AXIS_TSTRB,
        (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 OUT_DBG TKEEP" *)
        output wire [(C_AXIS_DATA_WIDTH/8)-1:0]             M_AXIS_TKEEP,
        (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 OUT_DBG TVALID" *)
        output wire                                         M_AXIS_TVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 OUT_DBG TREADY" *)
        input wire                                          M_AXIS_TREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 OUT_DBG TLAST" *)
        output wire                                         M_AXIS_TLAST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 OUT_DBG TUSER" *)
        output wire [TUSER_WIDTH-1:0]                       M_AXIS_TUSER,     
        (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 OUT_DBG TDEST" *)
        output wire [TDEST_WIDTH-1:0]                       M_AXIS_TDEST,               

        (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 S_AXI_ACLK CLK" *)
        (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF IN_DBG:OUT_DBG, ASSOCIATED_RESET S_AXI_ARESETN" *)
        input wire  clk,
        // Global Reset Signal. This Signal is Active LOW
        input wire  S_AXI_ARESETN,

        output reg  [191:0]                                 debug_slot,
        input wire                                          rst 
        

    );
    
        reg [63:0]                          time_counter;
        reg [63:0]                          byte_counter;
        reg [63:0]                          pkt_counter;
        reg [63:0]                          globalTimer;
        reg                                 active_counter;
        reg [63:0]                          inactive_cnt;
        wire [6:0]                          number_of_ones;
        reg  [6:0]                          number_of_ones_1d;  
        reg                                 tvalid_1d;
        reg                                 tready_1d;
        reg                                 tlast_1d;
    
        reg  [31:0]                         time_counter_lsb;
        reg  [31:0]                         time_counter_msb;
        
          //absolute timer
       always @(posedge clk) begin
          if(rst) globalTimer<= 0;
          else globalTimer <= globalTimer + 1;      
       end 
        

        always @( posedge clk ) begin
            if ( S_AXI_ARESETN == 1'b0 || rst == 1'b1) begin
                byte_counter        <= 'h0;
                time_counter        <= 'h0;
                active_counter      <= 1'b0;
                pkt_counter         <= 'h0;
                tvalid_1d           <= 1'b0;
                tready_1d           <= 1'b0;
                tlast_1d            <= 1'b0;
                number_of_ones_1d   <= 'h0;
                time_counter_lsb    <= 'h0;
                time_counter_msb    <= 'h0;
                inactive_cnt          <= 'h0;
            end 
            else begin    

                time_counter    <= (active_counter) ? time_counter + 1  : time_counter;
  
                if(~active_counter)inactive_cnt <= inactive_cnt + 1;

                if (S_AXIS_TVALID && S_AXIS_TREADY) begin
                    active_counter  <= 1'b1;
                end

                if (tvalid_1d && tready_1d) begin
                    byte_counter        <= byte_counter + number_of_ones_1d;
                    time_counter_lsb    <= time_counter[31:0];
                    time_counter_msb    <= time_counter[63:32];
                end

                if (tvalid_1d && tready_1d && tlast_1d) begin
                    pkt_counter     <= pkt_counter + 1;
                end 

                number_of_ones_1d   <= number_of_ones;
                tvalid_1d    <= S_AXIS_TVALID;
                tready_1d    <= S_AXIS_TREADY;
                tlast_1d     <= S_AXIS_TLAST; 
               
            end
        end    

        always @( posedge clk ) begin
            debug_slot <={time_counter_lsb,time_counter_msb, byte_counter[31:0],byte_counter[63:32],pkt_counter[31:0],pkt_counter[63:32]};
        end

/*
        generate
            if (USE_KEEP == 1) begin  : count_using_keep
                counter64_7_v3 counter64_7_v3_i (
                    .x(S_AXIS_TKEEP         ),
                    .s(number_of_ones)
                );
            end
            else begin                : count_using_strb  
            counter64_7_v3 counter64_7_v3_i (
                    .x(S_AXIS_TSTRB         ),
                    .s(number_of_ones)
                );
            end
        endgenerate
*/

        // make bridge connections

        assign M_AXIS_TDATA     =   S_AXIS_TDATA;
        assign M_AXIS_TKEEP     =   S_AXIS_TKEEP;
        assign M_AXIS_TSTRB     =   S_AXIS_TSTRB;
        assign M_AXIS_TVALID    =   S_AXIS_TVALID;
        assign S_AXIS_TREADY    =   M_AXIS_TREADY;
        assign M_AXIS_TLAST     =   S_AXIS_TLAST;
        assign M_AXIS_TUSER     =   S_AXIS_TUSER;
        assign M_AXIS_TDEST     =   S_AXIS_TDEST;

`ifdef FORMAL
  always @(posedge clk) begin   
     if(!$initstate) begin
      assume(rst == 0 && S_AXI_ARESETN == 1);
      
      //constraints
   
      //-----//
      
      //Invariant 
      assume(time_counter <= globalTimer); 

      //verify a property
     assert(time_counter + inactive_cnt == globalTimer);
    // assert(0);

     end
     else begin
       assume(rst);
     end
  end
`endif


endmodule
