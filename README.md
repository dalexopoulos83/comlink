# comlink

This code is part of my master's thesis at Harokopio University of Athens (HUA). In the thesis I built a Visible Light Communication (VLC) link, where data is sent as changes in the brightness of an LED and picked up by a light detector.

This repository contains the Octave/MATLAB code that:

1. builds a **4-QAM (QPSK)** modulated test signal from random bits,
2. uploads it to an **Agilent arbitrary waveform generator** (over GPIB, using SCPI commands), which drives the LED,
3. captures the received signal with an **Agilent oscilloscope** (over USB, using SCPI commands),
4. demodulates the captured signal and calculates the **bit error rate (BER)**.

---

## Repository structure

All code is in the [`M4_QAM Code/`](M4_QAM%20Code/) folder.

| File | Role |
|------|------|
| `qam_led_1m.m` | Main script. Builds the QAM signal, sends it, receives it, demodulates it and calculates the BER. |
| `generatorConnection.m` | Opens the VISA connection to the signal generator at `GPIB0::10::0::INSTR` and resets it (`*RST`). |
| `generatorUploader.m` | Uploads a waveform to the generator's volatile memory, sets up its output and checks for instrument errors. |
| `closeGeneratorConnection.m` | Closes and deletes the generator connection object. |
| `oscilloscopeConnection.m` | Opens the VISA connection to the oscilloscope over USB (`USB0::2391::1416::cn50097489::0::INSTR`). |
| `led_oscilloscopeDataReader.m` | Sets up the oscilloscope, takes one triggered capture and returns the waveform as a numeric vector. |
| `closeOscilloscopeConnection.m` | Closes and deletes the oscilloscope connection object. |
| `led_oscilloscopeDataReader.asv` | MATLAB editor autosave backup. It is not used and can be ignored. |

---

## How the link works

```
 random bits ──► 4-QAM modulator ──► passband waveform ──► signal generator ──► LED
                                                                                │  (light, over the air)
 BER ◄── bit compare ◄── QAM demodulator ◄── sync & resample ◄── oscilloscope ◄─┘  photodetector
```

### 1. Transmitter (in `qam_led_1m.m`)

**Parameters**

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `Rb` | 1 kHz | Nominal symbol rate used to build the waveform |
| `Fc` | 2 kHz (`2*Rb`) | Carrier frequency |
| `nSamps` | 32 | Samples per symbol |
| `Fs` | 32 kHz | Sampling frequency (`Rb*nSamps`) |
| `mlevel` | 4 | Number of constellation points (4-QAM) |
| `k` | 2 | Bits per symbol |
| `N` | 248 | Random data bits per frame |
| `Nt` | 256 | Total bits per frame (preamble + data) |
| `Spulse` | `[0 0 0 1 1 1 1 0]` | 8-bit sync preamble |

**Steps**

1. **Bit generation.** The script generates `N = 248` random bits (`randn(1,N) >= 0`). It puts the 8-bit preamble `Spulse` in front, giving a 256-bit frame (`data_i`). This frame is the reference used later for the BER.
2. **Bits to symbols.** Each pair of bits becomes one symbol from 0 to 3 (`bi2de`, MSB first). The frame is 128 symbols long.
3. **QAM mapping.** `qammod` maps the symbols onto the 4-QAM constellation. The real and imaginary parts become the in-phase (I) and quadrature (Q) components.
4. **Pulse shaping.** `rectpulse` holds each symbol for `nSamps = 32` samples (rectangular pulses).
   - Preamble symbols are scaled by `amplitude_sq = 1`.
   - Data symbols are scaled by `amplitude = 0.5`.

   Because the preamble is twice as strong as the data, the receiver can find the start of the frame.
5. **Up-conversion.** I is multiplied by `cos(2πFc·t)` and Q by `sin(2πFc·t)`. The passband signal is `I·cos − Q·sin`.
6. **Normalisation.** The waveform is divided by its maximum, so it stays between −1 and +1 (the range the generator's `DATA VOLATILE` command accepts), and rounded to 3 decimals. The result, `datastr`, has 4096 samples (128 symbols × 32 samples).

### 2. Sending the waveform: `generatorUploader.m`

1. Opens the generator with `generatorConnection` (VISA-GPIB, address 10, 80 s timeout, large output buffer, `*RST`).
2. Turns the sample vector into one comma-separated SCPI command, `DATA VOLATILE,<v1>,<v2>,...`, and sends it. Then it sends `*WAI` so the generator finishes loading before it gets the next command.
3. Sets up the output:
   - burst settings (`BURST:MODE TRIG`, `BURST:NCYC 1`, `TRIG:SOUR BUS`, `TRIG:SLOP POS`, `BURST:STAT ON`),
   - user waveform from volatile memory (`FUNC USER`, `FUNC:USER VOLATILE`),
   - trigger output (`OUTPUT:TRIG ON`) and main output (`OUTPUT ON`).
4. `APPLY:USER 0.75e3, .4 VPP, 0` plays the whole 4096-point waveform at a repetition rate of **750 Hz**, with **0.4 Vpp** amplitude and **0 V** offset. This setting, not `Rb`, decides the physical symbol rate on the LED. Note that on Agilent 33200-series generators, `APPLy` also turns off burst mode, so the output repeats continuously; check this against your model's manual.
5. Reads `SYST:ERR?` and prints whether the instrument reported an error.
6. Closes the connection.

### 3. Capturing the received signal: `led_oscilloscopeDataReader.m`

1. Opens the oscilloscope with `oscilloscopeConnection` (VISA-USB, 1 MB input buffer).
2. Sets up the oscilloscope:
   - reset and autoscale, channel 1 probe at 10×,
   - timebase **50 µs/div**, offset **600 µs**,
   - edge trigger on channel 1 at **−1.0 V**. The code comments give trigger levels used at other LED–detector distances, e.g. −0.85 V at 1 m and −1.8 V at 60 cm.
3. Runs a `:SINGLE` acquisition and asks for **10240 raw points** from channel 1 in ASCII format.
4. Removes the 10-character block header from the reply, turns the text into a numeric vector with `str2num` and returns it.
5. Closes the connection.

### 4. Receiver and BER (in `qam_led_1m.m`)

After `generatorUploader(datastr)` the script runs a capture loop. It runs once by default; raise the loop bound to repeat the measurement.

1. **Capture.** Calls `led_oscilloscopeDataReader` and plots the raw capture.
   > The `keyboard` statement pauses the script so you can look at the capture. Type `dbcont` (Octave) or `return` (MATLAB) to continue.
2. **Frame detection.**
   - Start threshold: the minimum of the first 5000 samples, minus 0.4.
   - End threshold: the minimum of the remaining samples, minus 0.4.
   - Start of the frame: the first sample above the start threshold with index below 3000.
   - End of the frame: the first sample above the end threshold with index above 7000.
3. **Length check.** The frame is used only if it is between 5500 and 7500 samples long. Otherwise the capture is marked as a bad trigger.
4. **Resampling.** `resample` stretches or shrinks the frame to exactly `Nt*nSamps/2 = 4096` samples, so it lines up with the transmitted waveform.
5. **Coherent down-conversion.** The frame is multiplied by the same `cos` and `sin` carriers used in the transmitter, to get I and Q.
6. **Integrate-and-dump.** `intdump(…, nSamps)` averages each block of 32 samples, giving one value per symbol.
7. **Detection.** The I and Q values are combined into `I − jQ`, scaled back by `max(baseband)` and demodulated with `qamdemod(…, 4, pi)`. The phase offset of π corrects the phase inversion in the receive path.
8. **Bits and BER.** `de2bi` turns the symbols back into bits. `biterr` compares them with the transmitted frame, **without the 8 preamble bits**. The number of bit errors is added to the `ber` vector.

**Error codes stored in `ber`.** If a capture cannot be processed, a code above the maximum possible error count (248) is stored instead, so failed captures are easy to tell apart:

| Code | Meaning |
|------|---------|
| `509` | No start or end point found in the expected index ranges (`null matrix`) |
| `510` | Frame length outside 5500–7500 samples (`Bad Triggering`) |
| `511` | No sample above the start or end threshold (`Bad Thresold`) |
| `512` | The oscilloscope returned no data (`Bad Data Redaing`) |

A commented-out `csvwrite` line can save the `ber` vector to a `.dat` file, which is useful for long measurement runs at different distances.

5. **Constellation plots.** Finally, figure 2 shows the transmitted constellation (preamble + data, "Tx") and the received constellation ("Rx").

---

## Requirements

- **MATLAB** or **GNU Octave**. With Octave you need these packages:
  - `communications`: `qammod`, `qamdemod`, `bi2de`, `de2bi`, `rectpulse`, `intdump`, `biterr`
  - `signal`: `resample`
- **Instrument control.** The instrument scripts use `visa(...)`, `instrfind(...)`, `fopen`, `fprintf` and `fscanf` on VISA objects. These come from MATLAB's Instrument Control Toolbox. In Octave they may need to be changed to the `instrument-control` package functions (`gpib`, `usbtmc`).
- **A VISA library**, e.g. Keysight/Agilent IO Libraries Suite, plus a GPIB interface for the generator.
- **Hardware:**
  - an Agilent arbitrary waveform generator on GPIB address 10,
  - an Agilent oscilloscope connected over USB,
  - an LED transmitter driven by the generator and a photodetector connected to oscilloscope channel 1.

## Running it

1. Connect the instruments. If your VISA resource strings are different, edit them in `generatorConnection.m` and `oscilloscopeConnection.m`.
2. Set the oscilloscope trigger level in `led_oscilloscopeDataReader.m` to match the LED–detector distance.
3. Open `M4_QAM Code/` as the working folder and run:
   ```matlab
   qam_led_1m
   ```
4. When the script stops at `keyboard`, check the capture and continue (`dbcont` / `return`). The BER result is printed and the constellations are plotted.

## Known limitations

- The frame-detection thresholds, index windows (300/3000, 7000/8900) and length limits (5500–7500) were tuned for this particular setup and timebase. They need to be retuned for other distances, rates or instruments.
- In the frame detection, each `find` call that sets `data_start` or `data_end` is immediately replaced by the next one. Only the `< 3000` and `> 7000` conditions are actually used.
- Down-conversion assumes the carrier phase is already aligned. There is no carrier or timing recovery apart from the preamble-based frame detection and resampling.
- If no capture succeeds, `Rx_x` is never set and the final Rx constellation plot fails.
