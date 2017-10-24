# AHB-Lite Memory

The Roa Logic AHB-Lite Memory IP is a fully parameterized soft IP implementing on-chip memory for access by an AHB-Lite based Master. All signals defined in the *AMBA 3 AHB-Lite v1.0* specifications are fully supported.

The IP supports a single AHB-Lite based host connection and enables address & data widths, memory depth & target technology to be specified via parameters. An option to register the memory output is also provided.

![AHB-Lite-Memory-PortDiag](assets/img/AHB-Lite-Memory-PortDiag.png)

## Documentation

- [Datasheet](DATASHEET.md)
  - [PDF Format](docs/ahb3lite_memory_datasheet.pdf)

## Features

- Full support for AMBA 3 AHB-Lite protocol
- Fully parameterized
- User-defined address and byte-aligned data widths supported
- Configurable memory depth, limited only by target technology capability
- Technology-specific memory cells instantiated automatically
- Combinatorial or registered data output

## Interfaces

- AHB-LIte

## License

Released under the [RoaLogic BSD license](LICENSE.md)

## Dependencies
This release requires the
- ahb3lite package found here https://github.com/RoaLogic/ahb3lite_pkg
- memorys IPs found here https://github.com/RoaLogic/memory



