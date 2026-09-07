import std/unittest
import nim_esphome

suite "nim-esphome embedded DSP and control utilities":
  test "pid controller":
    var pid = newPIDController(kp = 2.0'f32, ki = 0.5'f32, kd = 0.1'f32, minOutput = -50.0'f32, maxOutput = 50.0'f32)

    # Step 1: Unclamped P + I calculation (error = 2.0, dt = 0.5)
    # P = 2.0 * 2.0 = 4.0; I = 0.5 * (2.0 * 0.5) = 0.5; D = 0.0 -> Total = 4.5
    let out1 = pid.update(10.0'f32, 8.0'f32, 0.5'f32)
    check out1 == 4.5'f32

    # Step 2: Unclamped P + I + D calculation with previous error state
    # error = 1.0, delta error = -1.0, dt = 0.5
    # P = 2.0; I = 0.5 * (1.0 + 0.5) = 0.75; D = 0.1 * (-1.0 / 0.5) = -0.2 -> Total = 2.55
    let out2 = pid.update(10.0'f32, 9.0'f32, 0.5'f32)
    check abs(out2 - 2.55'f32) < 1e-5

    # Step 3: Actuator saturation clamping on upper and lower bounds
    check pid.update(100.0'f32, 0.0'f32, 1.0'f32) == 50.0'f32
    check pid.update(0.0'f32, 100.0'f32, 1.0'f32) == -50.0'f32

    # Step 4: Test reset
    pid.reset()
    check pid.integral == 0.0'f32
    check pid.hasPrev == false

  test "moving average":
    var ma = newMovingAverage[4]()
    check ma.update(10.0'f32) == 10.0'f32
    check ma.update(20.0'f32) == 15.0'f32
    check ma.update(30.0'f32) == 20.0'f32
    check ma.update(40.0'f32) == 25.0'f32
    # Buffer full, next value displaces 10.0: (20 + 30 + 40 + 50) / 4 = 35.0
    check ma.update(50.0'f32) == 35.0'f32
    check ma.value() == 35.0'f32

  test "moving median rejects outliers":
    var mm = newMovingMedian[5]()
    discard mm.update(10.0'f32)
    discard mm.update(12.0'f32)
    # Outlier spike!
    discard mm.update(999.0'f32)
    discard mm.update(11.0'f32)
    let med = mm.update(13.0'f32)
    # Sorted: [10, 11, 12, 13, 999] -> median is 12
    check med == 12.0'f32

  test "low pass filter":
    var lpf = newLowPassFilter(alpha = 0.2'f32)
    check lpf.update(100.0'f32) == 100.0'f32 # First sample initializes
    # Next sample: 0.2 * 200 + 0.8 * 100 = 40 + 80 = 120
    check lpf.update(200.0'f32) == 120.0'f32

  test "debouncer":
    var deb = newDebouncer(debounceTimeMs = 50'u32, initialVal = false)
    check deb.state == false

    # Bounce begins at t = 10
    discard deb.update(true, 10'u32)
    check deb.state == false
    check deb.rose == false

    # Bounces back low at t = 20
    discard deb.update(false, 20'u32)
    check deb.state == false

    # Goes high steadily at t = 30
    discard deb.update(true, 30'u32)
    check deb.state == false

    # Still high at t = 75 (< 50ms since t=30)
    discard deb.update(true, 75'u32)
    check deb.state == false

    # Reaches 50ms at t = 80 -> state becomes true
    discard deb.update(true, 80'u32)
    check deb.state == true
    check deb.rose == true
