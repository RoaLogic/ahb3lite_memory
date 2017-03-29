/////////////////////////////////////////////////////////////////
//                                                             //
//    ██████╗  ██████╗  █████╗                                 //
//    ██╔══██╗██╔═══██╗██╔══██╗                                //
//    ██████╔╝██║   ██║███████║                                //
//    ██╔══██╗██║   ██║██╔══██║                                //
//    ██║  ██║╚██████╔╝██║  ██║                                //
//    ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝                                //
//          ██╗      ██████╗  ██████╗ ██╗ ██████╗              //
//          ██║     ██╔═══██╗██╔════╝ ██║██╔════╝              //
//          ██║     ██║   ██║██║  ███╗██║██║                   //
//          ██║     ██║   ██║██║   ██║██║██║                   //
//          ███████╗╚██████╔╝╚██████╔╝██║╚██████╗              //
//          ╚══════╝ ╚═════╝  ╚═════╝ ╚═╝ ╚═════╝              //
//                                                             //
//    AHB3-Lite Single Port SRAM                               //
//                                                             //
/////////////////////////////////////////////////////////////////
//                                                             //
//             Copyright (C) 2016 ROA Logic BV                 //
//             www.roalogic.com                                //
//                                                             //
//    Unless specifically agreed in writing, this software is  //
//  licensed under the RoaLogic Non-Commercial License         //
//  version-1.0 (the "License"), a copy of which is included   //
//  with this file or may be found on the RoaLogic website     //
//  http://www.roalogic.com. You may not use the file except   //
//  in compliance with the License.                            //
//                                                             //
//    THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY        //
//  EXPRESS OF IMPLIED WARRANTIES OF ANY KIND.                 //
//  See the License for permissions and limitations under the  //
//  License.                                                   //
//                                                             //
/////////////////////////////////////////////////////////////////
 

module ahb3lite_sram1rw #(
  parameter MEM_SIZE          = 0,   //Memory in Bytes
  parameter MEM_DEPTH         = 256, //Memory depth
  parameter HADDR_SIZE        = 8,
  parameter HDATA_SIZE        = 32,
  parameter TECHNOLOGY        = "GENERIC",
  parameter REGISTERED_OUTPUT = "NO"
)
(
  input                       HRESETn,
                              HCLK,

  //AHB Slave Interfaces (receive data from AHB Masters)
  //AHB Masters connect to these ports
  input                       HSEL,
  input      [HADDR_SIZE-1:0] HADDR,
  input      [HDATA_SIZE-1:0] HWDATA,
  output reg [HDATA_SIZE-1:0] HRDATA,
  input                       HWRITE,
  input      [           2:0] HSIZE,
  input      [           2:0] HBURST,
  input      [           3:0] HPROT,
  input      [           1:0] HTRANS,
  output reg                  HREADYOUT,
  input                       HREADY,
  output                      HRESP
);


  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //
  import ahb3lite_pkg::*;

  localparam BE_SIZE        = (HDATA_SIZE+7)/8;

  localparam MEM_SIZE_DEPTH = 8*MEM_SIZE / HDATA_SIZE;
  localparam REAL_MEM_DEPTH = MEM_DEPTH > MEM_SIZE_DEPTH ? MEM_DEPTH : MEM_SIZE_DEPTH;
  localparam MEM_ABITS      = $clog2(REAL_MEM_DEPTH);
  localparam MEM_ABITS_LSB  = $clog2(BE_SIZE);
  

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  logic                  we;
  logic [BE_SIZE   -1:0] be;
  logic [HADDR_SIZE-1:0] waddr;
  logic                  contention;
  logic                  ready;

  logic [HDATA_SIZE-1:0] dout;


  //////////////////////////////////////////////////////////////////
  //
  // Functions
  //
  function logic [6:0] address_mask;
    //default value, prevent warnings
	 address_mask = 0;
	 
    //Which bits in HADDR should be taken into account?
    case (HDATA_SIZE)
          1024: address_mask = 7'b111_1111; 
           512: address_mask = 7'b011_1111;
           256: address_mask = 7'b001_1111;
           128: address_mask = 7'b000_1111;
            64: address_mask = 7'b000_0111;
            32: address_mask = 7'b000_0011;
            16: address_mask = 7'b000_0001;
       default: address_mask = 7'b000_0000;
    endcase
  endfunction //address_mask


  function logic [BE_SIZE-1:0] gen_be;
    input [           2:0] hsize;
    input [HADDR_SIZE-1:0] haddr;

    logic [127:0] full_be;
    logic [  6:0] haddr_masked;

    //get number of active lanes for a 1024bit databus (max width) for this HSIZE
    case (hsize)
       HSIZE_B1024: full_be = 'hffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff; 
       HSIZE_B512 : full_be = 'hffff_ffff_ffff_ffff;
       HSIZE_B256 : full_be = 'hffff_ffff;
       HSIZE_B128 : full_be = 'hffff;
       HSIZE_DWORD: full_be = 'hff;
       HSIZE_WORD : full_be = 'hf;
       HSIZE_HWORD: full_be = 'h3;
       default    : full_be = 'h1;
    endcase

    //generate masked address
    haddr_masked = haddr & address_mask();

    //create PSTRB
    gen_be = full_be[BE_SIZE-1:0] << haddr_masked;
  endfunction //gen_be


  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //

  //generate internal write signal
  //This causes read/write contention, which is handled by memory
  always @(posedge HCLK)
    if (HREADY) we <= HSEL & HWRITE & (HTRANS != HTRANS_BUSY) & (HTRANS != HTRANS_IDLE);
    else        we <= 1'b0;

  //decode Byte-Enables
  always @(posedge HCLK)
    if (HREADY) be <= gen_be(HSIZE,HADDR);

  //store write address
  always @(posedge HCLK)
    if (HREADY) waddr <= HADDR;


  //Is there read/write contention on the memory?
  assign contention = (waddr[MEM_ABITS_LSB +: MEM_ABITS] == HADDR[MEM_ABITS_LSB +: MEM_ABITS]) & we &
                      HSEL & HREADY & ~HWRITE & (HTRANS != HTRANS_BUSY) & (HTRANS != HTRANS_IDLE);

  //if all bytes were written contention is/can be handled by memory
  //otherwise stall a cycle (forced by N3S)
  //We could do an exception for N3S here, but this file should be technology agnostic
  assign ready = ~(contention & ~&be);


  /*
   * Hookup Memory Wrapper
   * Use two-port memory, due to pipelined AHB bus;
   *   the actual write to memory is 1 cycle late, causing read/write overlap
   * This assumes there are input registers on the memory
   */
  rl_ram_1r1w #(
    .ABITS      ( MEM_ABITS  ),
    .DBITS      ( HDATA_SIZE ),
    .TECHNOLOGY ( TECHNOLOGY ) )
  ram_inst (
    .rstn  ( HRESETn              ),
    .clk   ( HCLK                 ),

    .waddr ( waddr[MEM_ABITS_LSB +: MEM_ABITS] ),
    .we    ( we                   ),
    .be    ( be                   ),
    .din   ( HWDATA               ),

    .raddr ( HADDR[MEM_ABITS_LSB +: MEM_ABITS] ),
    .dout  ( dout                 )
  );

  //AHB bus response
  assign HRESP = HRESP_OKAY; //always OK

generate
  if (REGISTERED_OUTPUT == "NO")
  begin
      always @(posedge HCLK,negedge HRESETn)
        if (!HRESETn) HREADYOUT <= 1'b1;
        else          HREADYOUT <= ready;

      always_comb HRDATA = dout;
  end
  else
  begin
      always @(posedge HCLK,negedge HRESETn)
        if (!HRESETn) HREADYOUT <= 1'b1;
        else if (HTRANS == HTRANS_NONSEQ && !HWRITE) HREADYOUT <= 1'b0;
             else                                    HREADYOUT <= 1'b1;

      always @(posedge HCLK)
        if (HREADY) HRDATA <= dout;
  end
endgenerate

endmodule
