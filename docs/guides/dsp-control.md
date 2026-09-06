# Embedded DSP & Closed-Loop Control

This guide covers digital signal processing (DSP) filters, closed-loop PID control algorithms, and input debouncing provided by `nim_esphome/dsp`.

---

## Design Principles

The DSP utilities in `nim-esphome` are engineered specifically for microcontrollers:

1. **Zero Heap Allocation**: All filters use stack-allocated arrays and inline struct storage.
2. **Deterministic Time Complexity**: O(1) insertions and updates prevent jitter in real-time loops.
3. **Single-Precision Floating Point**: Uses 32-bit floats (`float32`), matching the hardware Floating Point Units (FPU) of ESP32 and ESP32-S3.

---

## PID Closed-Loop Controller

The `PIDController` implements an industrial Proportional-Integral-Derivative feedback algorithm with **anti-windup clamping** to prevent integral saturation when actuators hit physical limits.

### Tuning & Update Loop
```nim
import nim_esphome

# Initialize PID controller with gains and output bounds
var heaterPid = newPIDController(
  kp = 3.5'f32,
  ki = 0.8'f32,
  kd = 0.15'f32,
  minOutput = 0.0'f32,    # 0% heater power
  maxOutput = 100.0'f32   # 100% heater power (PWM duty cycle)
)

var lastTime = millis()

esphomeLoop:
  let now = millis()
  let dt = float32(now - lastTime) / 1000.0'f32
  if dt >= 1.0'f32: # Update every second
    lastTime = now

    let currentTemp = readTemperatureSensor()
    let targetTemp = 24.0'f32

    let power = heaterPid.update(targetTemp, currentTemp, dt)
    setHeaterPwmDuty(power)
    info("Thermostat", "Heater output power: " & $power & "%")
```

---

## Moving Average Filter (`MovingAverage[N]`)

The `MovingAverage` filter maintains a sliding circular buffer of $N$ samples in stack memory. It adds new samples and subtracts discarded samples in constant $O(1)$ time.

```nim
import nim_esphome

# 10-sample moving average filter
var adcFilter = newMovingAverage[10]()

esphomeLoop:
  let rawAdc = float32(readAnalogPin())
  let smoothAdc = adcFilter.update(rawAdc)
```

---

## Moving Median Filter (`MovingMedian[N]`)

Ultrasonic distance sensors (e.g. HC-SR04), optical rangefinders, and dirty analog ADC lines often experience sharp transient noise spikes. Linear filters (like moving averages) smear noise spikes across time. 

The `MovingMedian` filter sorts samples in place on the stack to extract the statistical median, cleanly rejecting impulse noise:

```nim
import nim_esphome

# 7-sample moving median filter
var distanceFilter = newMovingMedian[7]()

esphomeLoop:
  let rawDistance = readUltrasonicSensor()
  let cleanDistance = distanceFilter.update(rawDistance)
```

---

## Low-Pass Exponential Filter (`LowPassFilter`)

The `LowPassFilter` implements a single-pole Infinite Impulse Response (IIR) filter:

$$y[n] = \alpha \cdot x[n] + (1 - \alpha) \cdot y[n-1]$$

Where $\alpha \in [0.0, 1.0]$. Lower values of $\alpha$ provide heavier smoothing:

```nim
import nim_esphome

var lpf = newLowPassFilter(alpha = 0.1'f32)

let smoothedValue = lpf.update(noisySignal)
```

---

## Software Debouncer (`Debouncer`)

Mechanical switches, push buttons, and magnetic reed contacts vibrate mechanically upon contact, generating dozens of spurious high/low transitions over a span of 5–30 ms.

The `Debouncer` ensures a state change is only acknowledged after remaining stable for `debounceTimeMs` milliseconds:

```nim
import nim_esphome

var buttonDebounce = newDebouncer(debounceTimeMs = 40'u32)

esphomeLoop:
  let isPressed = (digitalRead(0) == Low)
  let isStablePressed = buttonDebounce.update(isPressed, millis())

  if buttonDebounce.rose:
    info("Button", "Clean button press registered!")

  if buttonDebounce.fell:
    info("Button", "Clean button release registered!")
```
