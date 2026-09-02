#include "WaveTable.h"
#include <CircularBuffer.hpp> // Ensure you have this library installed
#include <Wire.h>
#include <Entropy.h>

/*
Serial interaction
<W,0,0,0,0,0,0,0> : set wave parameters, <W,(1)channel,(2)wave type,(3)wave length,(4)wave amp,(5)wave inter-pulse length, (6) wave reps, (7) wave baseline>
<S,0> : set state
*/

const uint Fs = 5000;  // Teensy sampling rate

bool enforceEarlyLick = false;  // error out if the mouse licks pre-stim
uint lickMax = 20;              // how many licks are too many licks
uint lickDebounce = 0.05 * Fs;  // so as not to over-count licks, mouse would have to lick >= 20 Hz for this to under-count

bool waitForNextFrame = false;  // if frame counting wait for a new frame to start to present a stimulus
bool vacReward = true;          // whether to suck off reward using solenoid 2

bool rewardAll = false; // for pairing/shaping

uint contingentStim = 0;  // index of the analog channel that the animal is responding to / detecting

// time lengths
uint trigLen = Fs * 0.2;   // trigger lenght in seconds
uint respLen = Fs * 2;     // how long from stim start is a response considered valid,
uint valveLen = Fs * 1;    // how long to open reward valve in samples
uint consumeLen = Fs * 3;  // how long from reward administration does the animal have to consume the reward
uint vacLen = Fs * 1;      // how long to open reward valve in samples
uint removeLen = Fs * 1;
uint transmitLen = Fs * 1;

bool reportData = true;

// channels
// ins
const uint wheelChan = 14;  // analog in
const uint frameChan = 23;  // frame counter channel, interrupt
const uint lickChan = 22;   //lick channel
volatile uint16_t wheelVal = 0;
volatile int lickVal = 0;
// outs
const uint trigChan1 = 0;               // trigger channel;
const uint trigChan2 = 1;               // trigger channel;
const uint trigChan3 = 2;               // trigger channel;
const uint trigChan4 = 3;               // trigger channel;

const uint valveChan1 = 4;              // reward valve
const uint valveChan2 = 6;              // vac line valve for reward removal
volatile bool valveChan1State = false;  // reward valve
volatile bool valveChan2State = false;  // vac line valve for reward removal
const uint barcodePin = 7;

// state definitions
const uint IDLE = 0;
const uint RESET = 1;
const uint GO = 2;
const uint NOGO = 3;
const uint VALVEO = 5;
const uint VALVEC = 6;
const uint TRIGGER = 7;
const uint REWARD = 8;
const uint STIMULUS = 9;
const uint REMOVEREWARD = 11;
const uint TRIALEND = 12;
const uint VALVE2O = 13;
const uint VALVE2C = 14;
volatile uint State = IDLE;

// Behavior tracking
const uint HIT = 1;
const uint MISS = 2;
const uint CW = 3;
const uint FA = 4;
const uint LICK = 5;
volatile uint trialOutcome = 0;
volatile uint latestOutcome = 0;

// general timers/trackers
volatile bool stimEnd = false;

volatile bool respStart = true;
volatile bool respEnd = false;
volatile bool hasResponded = false;
volatile uint32_t respT = 0;

volatile uint lickCount = 0;
volatile uint lickLow = 0;
volatile bool firstLick = true;
volatile bool earlyStart = false;
volatile uint32_t earlyT = 0;

volatile bool dispStart = true;
volatile uint32_t dispT = 0;

volatile bool consumeStart = true;
volatile uint32_t consumeT = 0;

volatile bool removeStart = true;
volatile uint32_t removeT = 0;

volatile bool trialEndStart = true;
volatile uint32_t transmitT = 0;

volatile bool trigStart = true;
volatile bool trigEnd = false;
volatile uint32_t trigT = 0;

// waveform parameters to be set over serial for each of the 4 DAC channels
volatile uint waveType[4] = { 1, 1, 1, 1 };   // wave types: 0 = whale, 1 = square
volatile uint waveDur[4] = { 20, 0, 0, 0 };   // duration of pulse, fixed for whale right now, set via serial in ms, converted to sample points
volatile uint waveAmp[4] = { 0, 0, 0, 0 };    // max voltage amplitude, in 12bit - 0-4095
volatile uint waveIPI[4] = { 20, 0, 0, 0 };   // duration between pulses, set via serial in ms, converted to sample points
volatile uint waveReps[4] = { 5, 0, 0, 0 };   // number of times to repeat wave pulse and interpulse interval
volatile uint rampStep[4] = { 0, 0, 0, 0 };   // specific to ramping variables
volatile uint whaleStep[4] = { 0, 0, 0, 0 };  // specific to asymcosin variables
volatile float gaussStep[4] = {0.0, 0.0, 0.0, 0.0};  // specific to gauss variables
volatile float gaussPhase[4] = {0.0, 0.0, 0.0, 0.0};  // specific to gauss variables
volatile uint waveBase[4] = { 0, 0, 0, 0 };   // baseline prior to stimulus onset, in ms, allows for offsets between the stimuli, set via serial in ms, converted to sample points
// waveform tracking
volatile uint wavIncrmntr[4] = { 0, 0, 0, 0 };  // for keeping track of where we are in a given stimulus presentation
volatile uint repCntr[4] = { 0, 0, 0, 0 };      // for keeping track of pulse repitions
volatile uint ipiCntr[4] = { 0, 0, 0, 0 };      // for keeping track of where we are in an interpulse interval
volatile uint BaseCntr[4] = { 0, 0, 0, 0 };     // for keeping track of where we are in a baseline period
volatile uint whaleCntr[4] = { 0, 0, 0, 0 };    // tracking whale stim
volatile uint gaussCntr[4] = { 0, 0, 0, 0 };    // tracking gauss stim
volatile uint waveParams[7] = { 0, 0, 0, 0, 0, 0, 0 };
volatile bool inIpi[4] = { false, false, false, false };
volatile bool inBase[4] = { true, true, true, true };
volatile bool stimOn[4] = { true, true, true, true };
volatile bool stimBegin[4] = { false, false, false, false };
volatile uint curVal[4] = { 0, 0, 0, 0 };
volatile uint chanSelect = 0;  //
const uint waveMax = 4095;     // it's a 12bit dac, so this will always be the max voltage out

// Serial coms

// Define a safe struct holding exactly one sample's worth of data
struct TelemetryPacket {
  uint32_t loopNum;
  uint32_t frameNum;
  uint stateNum;
  uint outcomeNum;
  uint16_t val0;
  uint16_t val1;
  int lick;
  uint16_t wheel;
  bool v1State;
  bool v2State;
  uint barcode;
};

// Create a buffer that can hold 64 packets in RAM. 
// At 2 kHz, a size of 64 provides a generous 32ms safety cushion for PC lag.
CircularBuffer<TelemetryPacket, 64> telemetryQueue;

const byte numChars = 255;
char receivedChars[numChars];
volatile bool newData = false;
volatile char msgCode;
uint param_id;
uint param_val;

// Counters
volatile uint32_t loopCount = 0;
volatile uint32_t frameCount = 0;
volatile uint32_t curFrame = 0;       // for waiting for next frame to begin trial
volatile uint32_t lastFrame = 0;      // for triggering frames of a camera
volatile bool frameWaitStart = true;  // for waiting for next frame to begin trial

// barcode
volatile uint32_t barcode;

const uint barcodeInterval = Fs * 5;     // send a barcode every n secs
const uint barcodeTime = Fs * 0.03;      // time of each ttl bit
const uint barcodeInitTime = Fs * 0.01;  // sending hi/lo to mark begin and end of barcode
const uint barcodecloseTime = Fs * 0.01;    // sending hi/lo to mark begin and end of barcode

const uint32_t barcodeMax = 4294967295;
const uint32_t barcodeBits = 32;
volatile uint32_t barcodeDigit;
volatile uint32_t bitIdx = 0;

volatile bool initcodeStart = true;
volatile bool barcodeStart = false;
volatile bool closecodeStart = false;

volatile bool barcodeOn = false;
volatile bool initcodeOn = false;
volatile bool initState = false;
volatile bool closeState = false;
volatile bool closecodeOn = false;

volatile uint32_t barcodeT = 0;
volatile uint32_t barcodeEndT = 0;
volatile uint32_t initT = 0;
volatile uint32_t closeT = 0;
volatile uint32_t initCount = 0;
volatile uint32_t closeCount = 0;
volatile uint32_t closecodeT = 0;

// objs
volatile bool requestDacZero = false;
IntervalTimer t1;

// ====================================================================
// FORWARD DECLARATIONS (FUNCTION PROTOTYPES)
// Tells the C++ compiler exactly what functions are in this file
// ====================================================================
void ohBehave();
void pollData();
void dataReport();
void recvSerial();
void parseData();
void genBarcode();
void waveWrite();
void goNoGo();
void justStim();
void justReward();
void removeReward();
void endOfTrialCleanUp();
void frameCounter();
void open_valve1();
void open_valve2();
void close_valve1();
void close_valve2();
void fireTrig();
void queueTelemetry();
int linspace(float const n, float const d1, float const d2, int const i);

void setup() {

  analogReadResolution(10);
  Serial.begin(115200);
  Wire.begin();
  
  // Give the DAC a moment to wake up physically
  delay(100); 

  // ==========================================
  // HAND-MADE MCP4728 INITIALIZATION (Library-Free)
  // ==========================================
  Wire.beginTransmission(0x60);
  // 1. Set all channels to use Internal 2.048V Reference (VREF)
  // 0x80 selects VREF config, 0x0F applies it to all 4 channels (A,B,C,D)
  Wire.write(0x80 | 0x0F); 
  
  // 2. Set all channels to use 2x Gain (Allows output to span up to ~4.096V)
  // 0xC0 selects Gain config, 0x0F applies 2x gain to all channels
  Wire.write(0xC0 | 0x0F); 
  
  // 3. Set Power-Down registers to Normal Operation (Awake)
  // 0xA0 selects Power-Down config, 0x00 leaves all channels active/on
  Wire.write(0xA0 | 0x00);
  Wire.endTransmission();
  // ==========================================

  Wire.setClock(1000000); // Maximize your I2C speed to 1 MHz

  // setup io
  attachInterrupt(frameChan, frameCounter, RISING);

  pinMode(valveChan1, OUTPUT);
  digitalWrite(valveChan1, LOW);

  pinMode(valveChan2, OUTPUT);
  digitalWrite(valveChan2, LOW);

  pinMode(trigChan1, OUTPUT);
  digitalWrite(trigChan1, LOW);

  pinMode(trigChan2, OUTPUT);
  digitalWrite(trigChan2, LOW);

  pinMode(trigChan3, OUTPUT);
  digitalWrite(trigChan3, LOW);

  pinMode(trigChan4, OUTPUT);
  digitalWrite(trigChan4, LOW);

  pinMode(lickChan, INPUT_PULLDOWN);

  pinMode(barcodePin, OUTPUT);  // initialize digital pin
  digitalWrite(barcodePin, LOW);

  // Initialize the hardware entropy engine
  Entropy.Initialize(); 
  barcode = Entropy.random();

  // start main interrupt timer program at specified sample rate
  t1.begin(ohBehave, 1E6 / Fs);
}

// functions called by timer should be short, run as quickly as
// possible, and should avoid calling other functions if possible.

void ohBehave() {
  // 1. TIMING CRITICAL: Read physical sensors and advance tracking ticks
  pollData();    // Keeps your 2 kHz sensor sampling flawless
  genBarcode();  // Keeps your bit timing perfectly uniform
  loopCount++;

  // STATE MACHINE 
  switch (State) {
    case IDLE:
      break;

    case RESET:
      loopCount = 0;
      frameCount = 0;
      barcode = Entropy.random(); // Fast hardware engine read
      State = IDLE;
      break;

    case GO:
    case NOGO:
      goNoGo(); // Execute stimulus monitoring and response checks
      break;

    case TRIGGER:
      fireTrig();
      break;

    case VALVEO:
      open_valve1();
      break;

    case VALVEC:
      close_valve1();
      break;

    case REWARD:
      justReward();
      break;

    case STIMULUS:
      justStim(); // Generates your smooth linear-interpolated Gaussian wave
      break;

    case REMOVEREWARD:
      removeReward();
      break;

    case TRIALEND:
      endOfTrialCleanUp();
      break;

    case VALVE2O:
      open_valve2();
      break;

    case VALVE2C:
      close_valve2();
      break;

    default:
      State = IDLE;
      break;
  }

  queueTelemetry();

}

// State functions
void goNoGo() {
  
  if (waitForNextFrame && frameWaitStart) {  
    curFrame = frameCount;
    frameWaitStart = false;
  } else if (!waitForNextFrame || frameCount > curFrame) {  
    
    // 1. RUN WAVEFORM UPDATE ENGINE: This computes your smooth Gaussian interpolation
    waveWrite();                                            

    // CASE A: Stimulus has not physically started playing yet (Baseline / Pre-stim window)
    if (!stimBegin[contingentStim]) {
      if (enforceEarlyLick) {
        if (lickVal == HIGH && firstLick) {
          lickCount = 1;
          firstLick = false;
        } else if (lickLow < lickDebounce) {
          if (lickVal == LOW) {
            lickLow++;
          } else {
            lickLow = 0;
          }
        } else if (lickLow >= lickDebounce && lickVal == HIGH) {
          lickCount++;
          lickLow = 0;
        }
        
        // If mouse licks too much pre-stim, abort trial instantly
        if (lickCount > lickMax) {
          latestOutcome = LICK;
          lickCount = 0;
          lickLow = 0;
          firstLick = true;
          State = TRIALEND;
        }
      }
    } 
    
    // CASE B: Stimulus is active and the animal is inside the valid response window
    else if (stimBegin[contingentStim] && !respEnd) {
      if (respStart) {  
        respT = loopCount; // Lock precise frame-start timestamp
        respStart = false;
      }
      
      if (!hasResponded && lickVal == HIGH) {  
        hasResponded = true; // Lick captured!
      }

      // Check if response time window has run out
      if (loopCount - respT > respLen) {
        respEnd = true;
      }
    } 
    
    // CASE C: Response window closed. Evaluate behavioral outcome metrics.
    else if (respEnd) {  
      if (hasResponded) {  
        latestOutcome = (State == GO) ? HIT : FA;
      } else {  
        latestOutcome = (State == GO) ? MISS : CW;
      }

      // Route the trial state to reward delivery or jump to cleanup
      if (latestOutcome == HIT || (rewardAll && State == GO)) {
        State = REWARD;
      } else {
        State = TRIALEND;
      }
    }
  }
}

void justStim() {
  if (waitForNextFrame && frameWaitStart) {  
    curFrame = frameCount;
    frameWaitStart = false;
  } else if (!waitForNextFrame || frameCount > curFrame) {
    waveWrite();    
    if (stimEnd) {  
      State = TRIALEND;
    }
  }
}

void justReward() {
  if (dispStart) {
    dispT = loopCount;
    dispStart = false;
  }
  if (loopCount - dispT < valveLen) {
    open_valve1();
  } else {
    close_valve1();
    if (consumeStart) {
      consumeT = loopCount;
      consumeStart = false;
    }
    if (loopCount - consumeT > consumeLen) {
      State = vacReward ? REMOVEREWARD : TRIALEND;
    }
  }
}

void removeReward() {
  if (removeStart) {
    removeT = loopCount;
    removeStart = false;
    open_valve2();
  } else if (loopCount - removeT > removeLen) {
    State = TRIALEND;
    close_valve2();
  }
}

void endOfTrialCleanUp() {
  // REMOVED from the very top so it doesn't loop 2,000 times a second!

  if (trialEndStart) {
    // FIXED: Captures the trial outcome exactly ONCE when cleanup begins
    trialOutcome = latestOutcome; 

    trialEndStart = false;
    transmitT = loopCount;

    // general end of trial/state reset
    for (int i = 0; i < 4; i++) {
      stimOn[i] = true;
      stimBegin[i] = false;
      inBase[i] = true;
      BaseCntr[i] = 0;
      repCntr[i] = 0;
      whaleCntr[i] = 0;
      gaussCntr[i] = 0;
      gaussPhase[i] = 0.0; // Cleanly resets your float phase accumulator
      wavIncrmntr[i] = 0;
      inIpi[i] = false;
      ipiCntr[i] = 0;
      curVal[i] = 0;
    }
    
    close_valve1();
    close_valve2();
    digitalWrite(trigChan1, LOW);
    digitalWrite(trigChan2, LOW);
    digitalWrite(trigChan3, LOW);
    digitalWrite(trigChan4, LOW);

    requestDacZero = true; 
    
    stimEnd = false;
    respEnd = false;
    hasResponded = false;
    respStart = true;
    dispStart = true;
    consumeStart = true;
    removeStart = true;
    frameWaitStart = true;
    lickCount = 0;
    lickLow = 0;
    firstLick = true;
  } 
  else if (loopCount - transmitT > transmitLen) {
    trialEndStart = true;
    trialOutcome = 0;
    latestOutcome = 0;
    State = IDLE;
  }
}

void fireTrig() {
  // fire a digital pulse on all trigger channels
  if (trigStart) {
    trigT = loopCount;
    trigStart = false;
  }
  if (loopCount - trigT > trigLen) {
    State = IDLE;
    trigStart = true;
    digitalWrite(trigChan1, LOW);
    digitalWrite(trigChan2, LOW);
    digitalWrite(trigChan3, LOW);
    digitalWrite(trigChan4, LOW);
  } else {
    digitalWrite(trigChan1, HIGH);
    digitalWrite(trigChan2, HIGH);
    digitalWrite(trigChan3, HIGH);
    digitalWrite(trigChan4, HIGH);
  }
}

void waveWrite() {
  if (!stimEnd) {
    // Waveform generator loop
    for (int i = 0; i < 4; i++) {  
      if (waveDur[i] <= 0) {       
        stimOn[i] = false;
      }
      if (stimOn[i]) {                       
        if (inBase[i] && waveBase[i] > 0) {  
          curVal[i] = 0;                     
          BaseCntr[i]++;                     
          if (BaseCntr[i] >= waveBase[i]) {
            inBase[i] = false;  
            BaseCntr[i] = 0;    
          }
        } else if (inIpi[i]) {             
          curVal[i] = 0;                   
          ipiCntr[i]++;                    
          if (ipiCntr[i] >= waveIPI[i]) {  
            inIpi[i] = false;              
            ipiCntr[i] = 0;                
          }
        } else {  
          stimBegin[i] = true;     
          if (waveType[i] == 0) {  // Whale stim
            if (wavIncrmntr[i] % whaleStep[i] == 0) {
              curVal[i] = map(asymCos[whaleCntr[i]], 0, waveMax, 0, waveAmp[i]);
              whaleCntr[i]++;
            }
          } else if (waveType[i] == 1) {  // Square wave
            curVal[i] = waveAmp[i];
          } else if (waveType[i] == 2) {  // Ramp up
            curVal[i] = linspace((float)waveDur[i], 0, (float)waveAmp[i], wavIncrmntr[i]);
          } else if (waveType[i] == 3) {  // Ramp down
            curVal[i] = linspace((float)waveDur[i], (float)waveAmp[i], 0, wavIncrmntr[i]);
          } else if (waveType[i] == 4) {  // Pyramid
            if (wavIncrmntr[i] < waveDur[i] / 2) {
              curVal[i] = linspace((float)waveDur[i] / 2, 0, (float)waveAmp[i], wavIncrmntr[i]);
            } else {
              curVal[i] = linspace((float)waveDur[i] / 2, (float)waveAmp[i], 0, wavIncrmntr[i] - waveDur[i] / 2);
            }
          } else if (waveType[i] == 5 && waveDur[i] > 0) {  // Gauss (Your beautifully fixed code)
            int indexA = (int)gaussPhase[i];
            int indexB = indexA + 1;

            if (indexB >= SamplesNum) {
              indexB = 0; 
            }

            float fraction = gaussPhase[i] - indexA;                            
            float fineInterp = (float)gauss[indexA] + fraction * ((float)gauss[indexB] - (float)gauss[indexA]);
            curVal[i] = (int)round((fineInterp / 4095.0) * (float)waveAmp[i]);

            gaussPhase[i] += gaussStep[i];

            if (gaussPhase[i] >= SamplesNum) {
              gaussPhase[i] -= SamplesNum; 
            }
          }
          wavIncrmntr[i] = wavIncrmntr[i] + 1;
        }

        if (wavIncrmntr[i] >= waveDur[i]) {    
          if (repCntr[i] < waveReps[i] - 1) {  
            repCntr[i] = repCntr[i] + 1;       
            whaleCntr[i] = 0;
            gaussCntr[i] = 0;
            gaussPhase[i] = 0.0;
            wavIncrmntr[i] = 0;  
            inIpi[i] = true;     
            curVal[i] = 0;
          } else {  
            repCntr[i] = 0;
            whaleCntr[i] = 0;
            gaussCntr[i] = 0;
            gaussPhase[i] = 0.0;
            wavIncrmntr[i] = 0;
            inIpi[i] = false;  
            stimOn[i] = false;
            curVal[i] = 0;
          }
        }
      }
    }

    // ==========================================
    // HARDENED I2C DAC WRITER
    // ==========================================
    // Instead of 4 separate slow individual writes, use the MCP4728 fast simultaneous pointer stream.
    // If your library version doesn't support an aggregate fast-write function, we can talk directly 
    // to Wire to blast all 8 bytes sequentially in a single fast I2C transmission:
    Wire.beginTransmission(0x60); // Your MCP4728 address
    for (int ch = 0; ch < 4; ch++) {
      // 0x40 is the Fast Write command prefix for MCP4728 channels
      // Splitting 12-bit curVal into two 8-bit bytes safely
      Wire.write(0x40 | ((curVal[ch] >> 8) & 0x0F)); 
      Wire.write(curVal[ch] & 0xFF);
    }
    Wire.endTransmission();
    // ==========================================

    // Check if all stimuli are done
    if (stimOn[0] || stimOn[1] || stimOn[2] || stimOn[3]) {
      // Still running...
    } else {
      stimEnd = true;
    }
  }
}


void pollData() {
  // get data in values
  wheelVal = analogRead(wheelChan);
  lickVal = digitalRead(lickChan);
}

void dataReport() {

  if (reportData) {
    // Empty the queue continuously as long as data remains inside it
    while (!telemetryQueue.isEmpty()) {
      TelemetryPacket outbound = telemetryQueue.shift(); // Pull the oldest data packet

      Serial.print("<");
      Serial.print(outbound.loopNum);    Serial.print(",");
      Serial.print(outbound.frameNum);   Serial.print(",");
      Serial.print(outbound.stateNum);   Serial.print(",");
      Serial.print(outbound.outcomeNum); Serial.print(",");
      Serial.print(outbound.val0);       Serial.print(",");
      Serial.print(outbound.val1);       Serial.print(",");
      Serial.print(outbound.lick);       Serial.print(",");
      Serial.print(outbound.wheel);      Serial.print(",");
      Serial.print(outbound.v1State);    Serial.print(",");
      Serial.print(outbound.v2State);    Serial.print(",");
      Serial.print(outbound.barcode);
      Serial.println(">");
    }
  }

}

// Call this at the very bottom of ohBehave() on every single tick
void queueTelemetry() {
  TelemetryPacket pack;
  
  pack.loopNum    = loopCount;
  pack.frameNum   = frameCount;
  pack.stateNum   = State;
  pack.outcomeNum = trialOutcome;
  pack.val0       = curVal[0];
  pack.val1       = curVal[1];
  pack.lick       = lickVal;
  pack.wheel      = wheelVal;
  pack.v1State    = valveChan1State;
  pack.v2State    = valveChan2State;
  pack.barcode    = barcodeDigit;

  // Ultra-fast memory copy into the circular ring buffer array (takes ~1 microsecond)
  telemetryQueue.push(pack);
}

void frameCounter() {
  frameCount++;
}

void recvSerial() {

  static boolean recvInProgress = false;
  static byte ndx = 0;
  const char startMarker = '<';
  const char endMarker = '>';
  char rc; // Removed volatile for clean hardware registry handling

  while (Serial.available() > 0 && newData == false) {
    rc = Serial.read();
    if (recvInProgress == true) {
      if (rc != endMarker) {
        receivedChars[ndx] = rc;
        ndx++;
        if (ndx >= numChars) {
          ndx = numChars - 1;
        }
      } else {
        receivedChars[ndx] = '\0';  
        recvInProgress = false;
        ndx = 0;
        newData = true; 
      }
    } else if (rc == startMarker) {
      recvInProgress = true;
    }
  }
}

void parseData() {  

  int cntr = 0;
  char *ptr;
  
  if (newData == true) {
    char *strtokIndx; 
    strtokIndx = strtok((char *)receivedChars, ",");  
    msgCode = *strtokIndx;
    
    if (msgCode == 'W') {  
      ptr = strtok(NULL, ",");
      while ((ptr != NULL) && (cntr < 7)) {
        waveParams[cntr] = atoi(ptr);
        cntr++;
        ptr = strtok(NULL, ",");
      }
      
      uint targetChan = waveParams[0];
      if (targetChan > 3) {
        Serial.println("Bad channel selection, defaulting to channel 0");
        targetChan = 0;
      }
      
      // Calculate temporal boundaries locally
      uint calculatedDur = (uint)round((waveParams[2] / 1000.0) * Fs);
      
      if ((waveParams[1] == 0 || waveParams[1] == 5) && calculatedDur < SamplesNum) {
        calculatedDur = SamplesNum;
      } else if ((waveParams[1] == 0 || waveParams[1] == 5) && calculatedDur % SamplesNum != 0) {
        calculatedDur = calculatedDur + (calculatedDur % SamplesNum);
      }
      
      uint calculatedIPI  = (uint)round((waveParams[4] / 1000.0) * Fs);
      uint calculatedBase = (uint)round((waveParams[6] / 1000.0) * Fs);
      uint calculatedRamp = (uint)ceil((float)waveParams[3] / calculatedDur);
      uint calculatedWhale = (uint)ceil((float)calculatedDur / SamplesNum);
      
      // Fixed Step Formula (Using the sample steps calculation approach)
      float calculatedGauss = (float)SamplesNum / (float)calculatedDur;

      // ========================================================
      // ATOMIC UPDATE ZONE: Safely push new parameters to arrays
      // ========================================================
      noInterrupts();
      chanSelect = targetChan;
      waveType[chanSelect] = waveParams[1];
      waveDur[chanSelect] = calculatedDur;
      waveAmp[chanSelect] = waveParams[3];
      waveIPI[chanSelect] = calculatedIPI;
      waveReps[chanSelect] = waveParams[5];
      waveBase[chanSelect] = calculatedBase;
      rampStep[chanSelect] = calculatedRamp;
      whaleStep[chanSelect] = calculatedWhale;
      gaussStep[chanSelect] = calculatedGauss; 
      interrupts();
      // ========================================================
       
    } else if (msgCode == 'S') {                                                             
      ptr = strtok(NULL, ",");
      noInterrupts();
      State = atoi(ptr);
      interrupts();
    } else if (msgCode == 'P') {  
      ptr = strtok(NULL, ",");
      param_id = atoi(ptr);
      ptr = strtok(NULL, ",");
      param_val = atoi(ptr);
      
      noInterrupts(); // Guard configuration updates
      if (param_id == 1) {  
        enforceEarlyLick = (param_val == 1);
      } else if (param_id == 2) {  
        lickMax = param_val;
      } else if (param_id == 3) {  
        waitForNextFrame = (param_val == 1);
      } else if (param_id == 4) {  
        contingentStim = param_val;
      } else if (param_id == 5) {  
        trigLen = (uint)round((param_val / 1000.0) * Fs);
      } else if (param_id == 6) {  
        respLen = (uint)round((param_val / 1000.0) * Fs);
      } else if (param_id == 7) {  
        valveLen = (uint)round((param_val / 1000.0) * Fs);
      } else if (param_id == 8) {  
        consumeLen = (uint)round((param_val / 1000.0) * Fs);     
      } else if (param_id == 10) {  
        transmitLen = (uint)round((param_val / 1000.0) * Fs);
      } else if (param_id == 11) {  
        removeLen = (uint)round((param_val / 1000.0) * Fs);
      } else if (param_id == 12) {  
        rewardAll = (param_val == 1);
      }
      interrupts();
    }
    newData = false;
  }
}


void genBarcode() {
  if (loopCount - barcodeEndT > barcodeInterval) { // Time to write a barcode
    
    if (initcodeStart){
      initT = loopCount;
      initcodeOn = true;
      initcodeStart = false;
      initCount = 0;
      barcodeDigit = 0;
      digitalWrite(barcodePin, initState);
    } 
    else if (initcodeOn){
      if (loopCount - initT >= barcodeInitTime && initCount < 2){
        barcodeDigit = !barcodeDigit;
        digitalWrite(barcodePin, barcodeDigit);
        initT = loopCount;
        initCount++;
      } 
      else if (loopCount - initT >= barcodeInitTime && initCount >= 2){
        initcodeOn = false;
        bitIdx = 0;
        
        // HARDENED OVERFLOW GUARD: Prevent silent 32-bit tracking overflows
        barcode++; 
        if (barcode >= barcodeMax) {
          barcode = 1; 
        }
        
        barcodeOn = true;
        barcodeT = loopCount;
        barcodeDigit = bitRead(barcode, bitIdx);
        digitalWrite(barcodePin, barcodeDigit);
      }
    } 
    else if (barcodeOn) {
      if (loopCount - barcodeT >= barcodeTime && bitIdx < barcodeBits - 1){
        bitIdx++;
        barcodeDigit = bitRead(barcode, bitIdx);
        digitalWrite(barcodePin, barcodeDigit);
        barcodeT = loopCount;
      } 
      else if (loopCount - barcodeT >= barcodeTime && bitIdx >= barcodeBits - 1){
        barcodeOn = false;
        closeT = loopCount;
        closecodeOn = true;
        closeCount = 0;
        barcodeDigit = 0;
        digitalWrite(barcodePin, barcodeDigit);
      }
    } 
    else if (closecodeOn){
      if (loopCount - closeT >= barcodecloseTime && closeCount < 2){
        barcodeDigit = !barcodeDigit;
        digitalWrite(barcodePin, barcodeDigit);
        closeCount++;
        closeT = loopCount;
      } 
      else if (loopCount - closeT >= barcodecloseTime && closeCount >= 2){
        digitalWrite(barcodePin, LOW);
        closecodeOn = false;
        initcodeStart = true;
        barcodeEndT = loopCount;
      }
    }
  }
}


void open_valve1() {
  digitalWrite(valveChan1, HIGH);
  valveChan1State = true;
}
void open_valve2() {
  digitalWrite(valveChan2, HIGH);
  valveChan2State = true;
}
void close_valve1() {
  digitalWrite(valveChan1, LOW);
  valveChan1State = false;
}
void close_valve2() {
  digitalWrite(valveChan2, LOW);
  valveChan2State = false;
}

int linspace(float const n, float const d1, float const d2, int const i) {
  float n1 = n - 1.0f;
  return (int)roundf(d1 + ((float)i * (d2 - d1) / n1));
}

void loop() {
  
  // 1. ASYNC TELEMETRY: Empty the ring buffer out to the PC as fast as USB allows
  if (reportData) {
    while (!telemetryQueue.isEmpty()) {
      // Pull the oldest unsent data packet out of the buffer
      TelemetryPacket outbound = telemetryQueue.shift(); 

      // Print using the struct data members
      Serial.print("<");
      Serial.print(outbound.loopNum);    Serial.print(",");
      Serial.print(outbound.frameNum);   Serial.print(",");
      Serial.print(outbound.stateNum);   Serial.print(",");
      Serial.print(outbound.outcomeNum); Serial.print(",");
      Serial.print(outbound.val0);       Serial.print(",");
      Serial.print(outbound.val1);       Serial.print(",");
      Serial.print(outbound.lick);       Serial.print(",");
      Serial.print(outbound.wheel);      Serial.print(",");
      Serial.print(outbound.v1State);    Serial.print(",");
      Serial.print(outbound.v2State);    Serial.print(",");
      Serial.print(outbound.barcode);
      Serial.println(">");
    }
  }


  // 2. ASYNC INBOUND: Listen for commands continuously at max CPU clock
  recvSerial(); 
  
  // 3. ASYNC DECODING: Parse packets (<W,0,0...>) safely without locking DACs
  if (newData) {
    parseData(); 
  }

  // ASYNC DAC CLEANUP: Handle the slow I2C communication safely out of the ISR
  if (requestDacZero) {
    requestDacZero = false; // Reset the flag immediately
    
    Wire.beginTransmission(0x60); // Your MCP4728 address
    for (int ch = 0; ch < 4; ch++) {
      Wire.write(0x40 | 0x00);     // 0x40 Fast Write prefix + upper 4 bits (all 0)
      Wire.write(0x00);            // Lower 8 bits (all 0)
    }
    Wire.endTransmission();
    // ========================================================
  }

}
