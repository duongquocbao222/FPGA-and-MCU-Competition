# FPGA and MCU Competition Project

An embedded-systems project combining an FPGA-based LED controller and an MCU-based digital clock with an alarm. The repository contains the Gowin FPGA design and simulation files, the SONiX SN32F407 MCU firmware, and technical/presentation reports.

> **Repository note:** The source tree contains two related implementations, `Chilli_FPGA` and `Chilli_MCU`. They are documented as separate subsystems below. The checked-in files do not by themselves prove that the FPGA and MCU exchange data as one integrated system; follow the wiring and test instructions for the individual boards.

## Table of Contents

- [Project Overview](#project-overview)
- [Subsystem 1: FPGA LED Controller](#subsystem-1-fpga-led-controller)
- [Subsystem 2: MCU Digital Clock and Alarm](#subsystem-2-mcu-digital-clock-and-alarm)
- [Repository Structure](#repository-structure)
- [Hardware and Software](#hardware-and-software)
- [Build and Run the FPGA Design](#build-and-run-the-fpga-design)
- [Simulate the FPGA Design](#simulate-the-fpga-design)
- [Build the MCU Firmware](#build-the-mcu-firmware)
- [Controls and Expected Behavior](#controls-and-expected-behavior)
- [Troubleshooting](#troubleshooting)
- [Technical Notes and Limitations](#technical-notes-and-limitations)
- [Reports](#reports)

## Project Overview

This repository explores two common embedded-design approaches:

1. **FPGA / digital logic:** implement button conditioning, a finite-state machine (FSM), PWM LED control, and UART transmit logic in Verilog.
2. **Microcontroller firmware:** implement a clock and alarm application in C using the SN32F407 MCU peripherals and supporting drivers.

The FPGA subsystem is useful for learning synchronous digital design, state machines, timing counters, serial communication, and testbench-based verification. The MCU subsystem demonstrates firmware structure, peripheral drivers, display/key handling, timer-based timekeeping, buzzer control, and persistent alarm settings.

## Subsystem 1: FPGA LED Controller

### Features

The FPGA design in `Chilli_FPGA/src/fpga_project-demo/src/` implements:

- A 27 MHz board clock input and a Gowin PLL IP configured to generate the internal system clock.
- A power-on reset counter.
- Two active-low push-button inputs with synchronizers and approximately 20 ms debounce filtering.
- Three LED modes: **LOW**, **HIGH**, and **AUTO**.
- PWM-based LED brightness control.
- An automatic “breathing” effect that gradually increases and decreases LED brightness.
- UART transmit logic that reports the selected mode to a serial terminal.

### Mode behavior

| Mode | LED behavior | Entry / transition |
|---|---|---|
| `LOW` | 25% PWM duty cycle | Initial mode; Button 1 toggles between LOW and HIGH |
| `HIGH` | 100% duty cycle | Button 1 from LOW |
| `AUTO` | Breathing effect | Button 2 from LOW or HIGH |
| Return to LOW | 25% PWM duty cycle | Button 1 while in AUTO |

The top-level FSM uses the following mode encoding:

- `2'b00`: LOW
- `2'b01`: HIGH
- `2'b10`: AUTO

On startup and mode changes, the design attempts to send a status string such as `MODE: LOW`, `MODE: HIGH`, or `MODE: AUTO` over UART.

### FPGA block architecture

```text
27 MHz board clock
        |
        v
   Gowin PLL IP
        |
        v
   Internal system clock
        |
        +--> Power-on reset
        |
        +--> Button synchronizers + debounce
        |              |
        |              v
        |        Mode-control FSM
        |              |
        |              +----------> PWM / breathing LED
        |              |
        |              +----------> UART string controller
        |                                   |
        |                                   v
        +----------------------------> UART TX pin
```

### Main Verilog modules

| File | Responsibility |
|---|---|
| `top_system.v` | Top-level wiring, reset, mode FSM, status-string controller |
| `debounce.v` | Synchronizes button inputs, filters button bounce, produces a one-cycle press pulse |
| `pwm_led.v` | PWM generation and automatic breathing brightness |
| `uart_tx_byte.v` | UART transmitter for one 8-bit byte |
| `gowin_pllo/gowin_pllo.v` | Gowin PLL IP wrapper and clock configuration |
| `fpga_project-demo.cst` | FPGA package pin locations and I/O electrical settings |
| `sim/tb_top_system.v` | Testbench for top-level behavior and button-bounce scenarios |

### FPGA I/O pin assignment

The checked-in constraints file `fpga_project-demo.cst` assigns these pins for the target board:

| Signal | Package pin | Purpose |
|---|---:|---|
| `clk_27m` | 4 | 27 MHz input clock |
| `btn1` | 35 | Button 1 |
| `btn2` | 36 | Button 2 |
| `led` | 27 | LED output |
| `uart_tx` | 34 | UART TX, noted in the source as connected to U2U_RXD |

**Important:** Confirm that the physical board matches these pin assignments before programming the FPGA. Do not assume the pin map is portable to another board.

## Subsystem 2: MCU Digital Clock and Alarm

The MCU firmware is under `Chilli_MCU/`. The Keil project targets the **SONiX SN32F407F** device and uses the ARM Compiler 6 / ARMCLANG toolchain as recorded in `project.uvprojx`.

### Features visible in the firmware

- Digital clock variables for hours, minutes, and seconds.
- Clock-setting modes for hour and minute.
- Alarm-setting modes for alarm hour and minute.
- Key scanning and a multiplexed segment-display driver.
- Buzzer control for alarm notification and short feedback beeps.
- I²C EEPROM read/write routines for saving and restoring alarm settings.
- Timer, GPIO, I²C, watchdog, and utility drivers.
- A 30-second timeout constant for leaving setting modes.
- An alarm trigger routine that toggles the buzzer and stops the alarm after a defined interval.

The source code includes a mode enumeration:

- `MODE_NORMAL`
- `MODE_SET_HOUR`
- `MODE_SET_MIN`
- `MODE_ALARM_HOUR`
- `MODE_ALARM_MIN`

### Key mapping in the firmware

The application maps four physical switch labels to key-scan codes:

| Physical switch | Firmware key | Typical role in the current code |
|---|---|---|
| SW3 | `KEY_1` | Enter/advance clock-setting mode; exits setting sequence |
| SW6 | `KEY_4` | Increase selected hour or minute |
| SW10 | `KEY_8` | Decrease selected hour or minute |
| SW16 | `KEY_13` | Enter/advance alarm-setting mode and save alarm settings |

Exact behavior depends on the current mode. Review the `switch (pressed_key)` block in `Chilli_MCU/Source/UserAPP/main.c` before changing key mappings.

### MCU source layout

| Path | Purpose |
|---|---|
| `Chilli_MCU/Source/UserAPP/main.c` | Application state, clock/alarm logic, key event handling, display rendering |
| `Chilli_MCU/Source/Driver/` | Peripheral-level drivers, including GPIO, timers, I²C, UART, watchdog, SysTick, and utility functions |
| `Chilli_MCU/Source/Module/Segment.c` | Segment-display functions |
| `Chilli_MCU/Source/Module/KeyScan.c` | Key scanning |
| `Chilli_MCU/Source/Module/Buzzer.c` | Buzzer functions |
| `Chilli_MCU/Source/Module/EEPROM.c` | EEPROM access functions |
| `Chilli_MCU/RTE/Device/SN32F407F/` | Device startup and system configuration |
| `Chilli_MCU/project.uvprojx` | Keil uVision project file |

## Repository Structure

```text
.
├── Chilli_FPGA/
│   ├── Chilli_BaoCaoKyThuat_FPGA.pdf
│   ├── src/
│   │   └── fpga_project-demo/
│   │       ├── fpga_project-demo.gprj
│   │       └── src/
│   │           ├── top_system.v
│   │           ├── debounce.v
│   │           ├── pwm_led.v
│   │           ├── uart_tx_byte.v
│   │           ├── gowin_pllo/
│   │           └── fpga_project-demo.cst
│   └── sim/
│       ├── tb_top_system.v
│       ├── top_system.v
│       ├── waveform/
│       └── work/                 # Generated simulator artifacts
├── Chilli_MCU/
│   ├── project.uvprojx
│   ├── Source/
│   │   ├── UserAPP/main.c
│   │   ├── Driver/
│   │   └── Module/
│   └── RTE/
└── Chilli_SlideBaoCaoTongHop.pdf
```

The `sim/work/` directory contains generated simulator files. These files are usually tool-generated and are not normally required to understand or maintain the RTL source.

## Hardware and Software

### FPGA subsystem

- A compatible Gowin FPGA board matching the project device and pin constraints.
- Board 27 MHz clock, two push buttons, and an LED.
- A USB-to-UART or onboard USB-UART connection for viewing status messages, connected according to the board schematic.
- **Gowin EDA** compatible with the project/device. The project file identifies device `GW1N-1P5C` / part `GW1N-UV1P5QN48XFC7/I6`.

### MCU subsystem

- SONiX SN32F407F development board or hardware compatible with the firmware and pin configuration.
- Segment display, buttons, buzzer, and I²C EEPROM hardware as required by the circuit.
- **Keil µVision** with ARM Compiler 6 / ARMCLANG.
- The SONiX SN32F4 Device Family Pack (DFP), as referenced by the project configuration.

The repository does not include a complete, verified bill of materials or a single wiring diagram in its source tree. Check the technical reports and the actual board schematic before assembling hardware.

## Build and Run the FPGA Design

1. Install and open a compatible version of **Gowin EDA**.
2. Open `Chilli_FPGA/src/fpga_project-demo/fpga_project-demo.gprj`.
3. Confirm that the target device matches the board and that all RTL and constraint files are included.
4. Review `fpga_project-demo.cst` and verify every pin against the board schematic.
5. Run synthesis and place-and-route/implementation.
6. Resolve any warnings or errors, then generate the programming file supported by the board (for example, the appropriate bitstream/programming file).
7. Program the FPGA using the supported programmer and board procedure.
8. Open a serial terminal on the correct COM port to inspect UART output.

The project files are provided, but this README does not claim that a fresh build or hardware test has been performed in this environment.

## Simulate the FPGA Design

The testbench is `Chilli_FPGA/sim/tb_top_system.v`. It generates a simulated 27 MHz clock and exercises button presses with short bounce-like transitions, then holds buttons long enough to pass the debounce interval. The intended scenarios include:

1. Startup and initial LOW status message.
2. Button 1 transition to HIGH.
3. Button 2 transition to AUTO.
4. Observation of the breathing LED behavior.

To run the simulation:

1. Open the project in a Verilog simulator that supports the design and its Gowin PLL model.
2. Add the RTL modules and `tb_top_system.v` to the simulation.
3. Make sure the PLL primitive/IP simulation model is available in the simulator library.
4. Set `top_system_tb` as the simulation top.
5. Run long enough to cover the button debounce delays and AUTO breathing interval.
6. Inspect `led`, `uart_tx`, and internal mode/state signals in the waveform viewer.

**Simulation caveat:** the PLL is vendor-specific. A generic simulator may need a Gowin simulation library or a simulation-only clock model. Existing waveform images are useful references, but they are not a substitute for rerunning the testbench after source changes.

## Build the MCU Firmware

1. Install Keil µVision and the SONiX SN32F4 DFP version required by the project.
2. Open `Chilli_MCU/project.uvprojx`.
3. Confirm that the target device is `SN32F407F` and that the device pack and include paths resolve correctly.
4. Review the source-file list in the project. The project configuration currently records ARM Compiler 6 / ARMCLANG.
5. Build the target and resolve missing-pack, include-path, or device-driver errors.
6. Connect the supported debug/programming adapter and select the correct target interface.
7. Flash the firmware and verify display, keys, buzzer, and EEPROM behavior on the hardware.

A successful build and flash depend on the matching SONiX device pack, programmer/debug adapter, and physical board. The repository configuration alone does not guarantee those are installed or available.

## Controls and Expected Behavior

### FPGA

- **Button 1:** switches LOW ↔ HIGH; while in AUTO, returns to LOW.
- **Button 2:** enters AUTO from LOW or HIGH.
- **LED:** displays the selected fixed brightness or the automatic breathing effect.
- **UART:** sends a mode-status message after startup and mode transitions.

The RTL assumes active-low buttons with pull-ups, as indicated by the input synchronizer reset values and pin constraints.

### MCU

- **SW3 / KEY_1:** moves through clock-setting states or returns to normal mode, depending on the current state.
- **SW6 / KEY_4:** increments the selected time value.
- **SW10 / KEY_8:** decrements the selected time value.
- **SW16 / KEY_13:** handles alarm-setting transitions and commits the configured alarm.
- **Segment display:** displays the current time or the selected setting values.
- **Buzzer:** provides short key feedback and alarm notification.
- **EEPROM:** stores the alarm settings so they can be restored after restart, when the stored marker and values are valid.

These descriptions follow the current application code. Verify the actual switch wiring and display hardware before relying on the mapping.

## Troubleshooting

### FPGA

- **LED does not respond:** check the board device, pin constraints, LED polarity, button polarity, and that the generated programming file was loaded.
- **Buttons seem unreliable:** verify pull-up configuration and confirm the board's button pins match the constraints. The debounce filter expects a stable state for about 20 ms.
- **No UART text:** verify the TX pin connection, COM port, baud rate, and common ground. The RTL sets a baud divider intended for approximately 115200 bps from its internal clock; confirm this against the actual PLL output and serial-terminal settings.
- **Simulation fails on the PLL:** add the correct Gowin primitive simulation library or replace the PLL with a simulation-only clock model in a separate test configuration.
- **Synthesis reports missing modules:** check that `debounce.v`, `pwm_led.v`, `uart_tx_byte.v`, and the PLL wrapper are included in the project.

### MCU

- **Device/header not found:** install the matching SONiX SN32F4 DFP and confirm Keil's pack/device selection.
- **Build succeeds but programming fails:** check the target adapter, selected flash algorithm, cable, power, and device selection.
- **Display or keys do not behave correctly:** check board-specific GPIO mapping, display wiring, key-scan configuration, and the peripheral initialization sequence.
- **Alarm settings are not retained:** verify the I²C EEPROM address, wiring, write-cycle timing, and EEPROM initialization.

## Technical Notes and Limitations

- The FPGA clock and timing parameters are written for the clock configuration in the supplied Gowin PLL wrapper. If the PLL or source clock changes, recalculate the PWM period, breathing-step interval, and UART baud divider.
- The top-level design uses a counter-based power-on reset. Validate reset timing and PLL lock behavior on the actual hardware.
- The current PWM comments describe a 1 ms PWM period and a 1 kHz PWM rate; the actual result depends on the generated clock frequency and counter parameters.
- The MCU project uses device-specific registers and drivers. It is not portable to another MCU without adaptation.
- Generated build outputs and simulator databases are not required for normal source maintenance and can often be regenerated by the relevant tools.
- This README describes the checked-in source and project metadata. Hardware operation, full integration between FPGA and MCU, and clean builds should be verified on the intended boards before being presented as confirmed results.

## Reports

- [FPGA Technical Report](Chilli_FPGA/Chilli_BaoCaoKyThuat_FPGA.pdf)
- [Combined Presentation Slides](Chilli_SlideBaoCaoTongHop.pdf)
- [MCU Technical Report](Chilli_MCU/Chilli_BaoCaoKyThuat_MCU.pdf)

## License

No explicit license file was found in the repository tree. Unless a license is added, reuse and redistribution permissions are not explicitly granted by this repository.
