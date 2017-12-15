/////////////////////////////////////////////////////////////////////
//   ,------.                    ,--.                ,--.          //
//   |  .--. ' ,---.  ,--,--.    |  |    ,---. ,---. `--' ,---.    //
//   |  '--'.'| .-. |' ,-.  |    |  |   | .-. | .-. |,--.| .--'    //
//   |  |\  \ ' '-' '\ '-'  |    |  '--.' '-' ' '-' ||  |\ `--.    //
//   `--' '--' `---'  `--`--'    `-----' `---' `-   /`--' `---'    //
//                                             `---'               //
//   AHB3-Lite Single Port SRAM                                    //
//                                                                 //
/////////////////////////////////////////////////////////////////////
//                                                                 //
//             Copyright (C) 2016-2017 ROA Logic BV                //
//             www.roalogic.com                                    //
//                                                                 //
//   This source file may be used and distributed without          //
//   restriction provided that this copyright statement is not     //
//   removed from the file and that any derivative work contains   //
//   the original copyright notice and the associated disclaimer.  //
//                                                                 //
//      THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY        //
//   EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED     //
//   TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS     //
//   FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR OR     //
//   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,  //
//   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT  //
//   NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;  //
//   LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)      //
//   HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN     //
//   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR  //
//   OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS          //
//   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.  //
//                                                                 //
/////////////////////////////////////////////////////////////////////

// +FHDR -  Semiconductor Reuse Standard File Header Section  -------
// FILE NAME      : ahb3lite_sram1rw.sv
// DEPARTMENT     :
// AUTHOR         : rherveille
// AUTHOR'S EMAIL :
// ------------------------------------------------------------------
// RELEASE HISTORY
// VERSION DATE        AUTHOR      DESCRIPTION
// 1.0     2017-04-01  rherveille  initial release
// ------------------------------------------------------------------
// KEYWORDS : AMBA AHB AHB3-Lite MEMORY SRAM
// ------------------------------------------------------------------
// PURPOSE  : General purpose AHB3Lite memory
// ------------------------------------------------------------------
// PARAMETERS
//  PARAM NAME        RANGE    DESCRIPTION              DEFAULT UNITS
//  MEM_SIZE          1+       Memory size              0       Bytes
//  MEM_DEPTH         1+       Memory Depth             256     Words
//  HADDR_SIZE        1+       Address bus size         8       bits
//  HDATA_SIZE        1+       Data bus size            32      bits
//  TECHNOLOGY                 Target technology        GENERIC
//  REGISTERED_OUTPUT [YES,NO] Registered outputs?      NO
// ------------------------------------------------------------------
// REUSE ISSUES 
//   Reset Strategy      : external asynchronous active low; HRESETn
//   Clock Domains       : HCLK, rising edge
//   Critical Timing     : 
//   Test Features       : na
//   Asynchronous I/F    : no
//   Scan Methodology    : na
//   Instantiations      : rl_ram_1r1w
//   Synthesizable (y/n) : Yes
//   Other               :                                         
// -FHDR-------------------------------------------------------------


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
  function logic [6:0] address_offset;
    //returns a mask for the lesser bits of the address
    //meaning bits [  0] for 16bit data
    //             [1:0] for 32bit data
    //             [2:0] for 64bit data
    //etc

    //default value, prevent warnings
    address_offset = 0;
	 
    //What are the lesser bits in HADDR?
    case (HDATA_SIZE)
          1024: address_offset = 7'b111_1111; 
           512: address_offset = 7'b011_1111;
           256: address_offset = 7'b001_1111;
           128: address_offset = 7'b000_1111;
            64: address_offset = 7'b000_0111;
            32: address_offset = 7'b000_0011;
            16: address_offset = 7'b000_0001;
       default: address_offset = 7'b000_0000;
    endcase
  endfunction //address_offset


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
    haddr_masked = haddr & address_offset();

    //create byte-enable
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
