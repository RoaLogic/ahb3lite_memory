Introduction
============

The Roa Logic AHB-Lite Memory IP is a fully parameterized soft IP implementing on-chip memory for access by an AHB-Lite based Master. All signals defined in the *AMBA 3 AHB-Lite v1.0* specifications are fully supported.

The IP supports a single AHB-Lite based host connection and enables address & data widths, memory depth & target technology to be specified via parameters. An option to register the memory output is also provided.

![AHB-Lite Memory System<span data-label="fig:ahb-lite-memory-sysdiag"></span>](assets/img/AHB-Lite-Memory-SysDiag.png)

Features
--------

-   Full support for AMBA 3 AHB-Lite protocol

-   Fully parameterized

-   User-defined address and byte-aligned data widths supported

-   Configurable memory depth, limited only by target technology capability

-   Technology-specific memory cells instantiated automatically

-   Combinatorial or registered data output

Functional Description
======================

The AHB-Lite Memory IP is a flexible, fully configurable, IP that enables designers to attach internal device memory to AHB-Lite based host. The width and depth of the memory, together with an optional registered output stage, are specified via parameters.

![AHB-Lite Memory Signalling<span data-label="fig:ahb-lite-memory-portdiag"></span>](assets/img/AHB-Lite-Memory-PortDiag.png)

The IP is designed to easily support a wide range of target technologies, automatically implementing technology-specific memory cells according to the chosen target. A generic behavioural implementation is also supported.

AHB-Lite Bus Locking Support
----------------------------

The *AMBA 3 AHB-Lite v1.0* protocol supports bus locking. Typically a locked transfer is used to ensure that a slave does not perform other operations between the read and write phases of a transaction. Given the AHB-Lite Memory IP performs no such operations, bus locking is not supported and does not provide the HMASTLOCK input associated with this capability

Configurations
==============

Introduction
------------

The size and implementation style of the memory is defined via HDL parameters. These are specified in the following section.

Core Parameters
---------------

| Parameter          | Type    | Default | Description               |
|:-------------------|:--------|:--------|:--------------------------|
| MEM\_DEPTH         | Integer | 256     | Memory Depth (Words)      |
| HADDR\_SIZE        | Integer | 32      | Address Bus Size (Bits)   |
| HDATA\_SIZE        | Integer | 32      | Data Bus Size (Bits)      |
| TECHNOLOGY         | String  | GENERIC | Implementation Technology |
| REGISTERED\_OUTPUT | String  | NO      | Is output registered?     |

### MEM\_DEPTH

MEM\_DEPTH defines the depth of the memory – i.e. number of HDATA\_SIZE words to be stored. The maximum depth supported is dependent upon the target technology chosen.

### HADDR\_SIZE

The HADDR\_SIZE parameter specifies the address bus size to connect to the AHB-Lite based host. The maximum size supported is 32 bits.

### HDATA\_SIZE

The HDATA\_SIZE parameter specifies the data bus size to connect to the AHB-Lite based host. The maximum size supported is 32 bits.

### TECHNOLOGY

The TECHNOLOGY parameter defines the target silicon technology and may be one of the following values:

| Parameter Value | Description                       |
|:----------------|:----------------------------------|
| GENERIC         | Behavioural Implementation        |
| N3X             | eASIC Nextreme-3 Structured ASIC  |
| N3XS            | eASIC Nextreme-3S Structured ASIC |

Details of the implementations corresponding to these parameter values can be found in Section 6, Technology Support

### REGISTERED\_OUTPUT

The REGISTERED\_OUTPUT parameter defines if the output of the memory is registered on assertion of the HREADY signal. It is specified as ‘YES’ or ‘NO’ (default).

Interfaces
==========

AHB-Lite Interface
------------------

The AHB-Lite interface is a regular AHB-Lite slave port. All signals are supported. See the *AMBA 3 AHB-Lite Specification* for a complete description of the signals.

| Port      | Size        | Direction | Description                   |
|:----------|:------------|:----------|:------------------------------|
| HRESETn   | 1           | Input     | Asynchronous active low reset |
| HCLK      | 1           | Input     | Clock Input                   |
| HSEL      | 1           | Input     | Bus Select                    |
| HTRANS    | 2           | Input     | Transfer Type                 |
| HADDR     | HADDR\_SIZE | Input     | Address Bus                   |
| HWDATA    | HDATA\_SIZE | Input     | Write Data Bus                |
| HRDATA    | HDATA\_SIZE | Output    | Read Data Bus                 |
| HWRITE    | 1           | Input     | Write Select                  |
| HSIZE     | 3           | Input     | Transfer Size                 |
| HBURST    | 3           | Input     | Transfer Burst Size           |
| HPROT     | 4           | Input     | Transfer Protection Level     |
| HREADYOUT | 1           | Output    | Transfer Ready Output         |
| HREADY    | 1           | Input     | Transfer Ready Input          |
| HRESP     | 1           | Input     | Transfer Response             |

### HRESETn

When the active low asynchronous HRESETn input is asserted (‘0’), the interface is put into its initial reset state.

### HCLK

HCLK is the interface system clock. All internal logic for the AMB3-Lite interface operates at the rising edge of this system clock and AHB bus timings are related to the rising edge of HCLK.

### HSEL

The AHB-Lite interface only responds to other signals on its bus when HSEL is asserted (‘1’). When HSEL is negated (‘0’) the interface considers the bus IDLE and negates HREADYOUT (‘0’).

### HTRANS

HTRANS indicates the type of the current transfer.

| HTRANS | Type   | Description                                                                              |
|:-------|:-------|:-----------------------------------------------------------------------------------------|
| 00     | IDLE   | No transfer required                                                                     |
| 01     | BUSY   | Connected master is not ready to accept data, but intents to continue the current burst. |
| 10     | NONSEQ | First transfer of a burst or a single transfer                                           |
| 11     | SEQ    | Remaining transfers of a burst                                                           |

### HADDR

HADDR is the address bus. Its size is determined by the HADDR\_SIZE parameter and is driven to the connected peripheral.

### HWDATA

HWDATA is the write data bus. Its size is determined by the HDATA\_SIZE parameter and is driven to the connected peripheral.

### HRDATA

HRDATA is the read data bus. Its size is determined by HDATA\_SIZE parameter and is sourced by the APB4 peripheral.

### HWRITE

HWRITE is the read/write signal. HWRITE asserted (‘1’) indicates a write transfer.

### HSIZE

HSIZE indicates the size of the current transfer.

| HSIZE | Size    | Description |
|:------|:--------|:------------|
| 000   | 8bit    | Byte        |
| 001   | 16bit   | Half Word   |
| 010   | 32bit   | Word        |
| 011   | 64bits  | Double Word |
| 100   | 128bit  |             |
| 101   | 256bit  |             |
| 110   | 512bit  |             |
| 111   | 1024bit |             |

### HBURST

HBURST indicates the transaction burst type – a single transfer or part of a burst.

| HBURST | Type   | Description                  |
|:-------|:-------|:-----------------------------|
| 000    | SINGLE | Single access                |
| 001    | INCR   | Continuous incremental burst |
| 010    | WRAP4  | 4-beat wrapping burst        |
| 011    | INCR4  | 4-beat incrementing burst    |
| 100    | WRAP8  | 8-beat wrapping burst        |
| 101    | INCR8  | 8-beat incrementing burst    |
| 110    | WRAP16 | 16-beat wrapping burst       |
| 111    | INCR16 | 16-beat incrementing burst   |

### HPROT

The HPROT signals provide additional information about the bus transfer and are intended to implement a level of protection.

| Bit\# | Value | Description                    |
|:------|:------|:-------------------------------|
| 3     | 1     | Cacheable region addressed     |
|       | 0     | Non-cacheable region addressed |
| 2     | 1     | Bufferable                     |
|       | 0     | Non-bufferable                 |
| 1     | 1     | Privileged Access              |
|       | 0     | User Access                    |
| 0     | 1     | Data Access                    |
|       | 0     | Opcode fetch                   |

### HREADYOUT

HREADYOUT indicates that the current transfer has finished.

### HREADY

HREADY indicates whether or not the addressed peripheral is ready to transfer data. When HREADY is negated (‘0’) the peripheral is not ready, forcing wait states. When HREADY is asserted (‘1’) the peripheral is ready and the transfer completed.

### HRESP

HRESP is the instruction transfer response and indicates OKAY (‘0’) or ERROR (‘1’). An error response causes an Instruction Bus Error Interrupt.

Resources
=========

Below are some example implementations for various platforms.

All implementations are push button, no effort has been undertaken to reduce area or improve performance.

| Platform | DFF | Logic Cells | Memory | Performance (MHz) |
|:---------|:----|:------------|:-------|:------------------|
|          |     |             |        |                   |
|          |     |             |        |                   |
|          |     |             |        |                   |

References
==========

Revision History
================

| Date        | Rev. | Comments |
|:------------|:-----|:---------|
| 01-Feb-2017 | 1.0  |          |
|             |      |          |
|             |      |          |
|             |      |          |


