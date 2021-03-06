/*

Analogue & Digital I/O

*/


float AI_AelerF = 700;
float AI_ElevaF = 700;
float AI_RuddeF = 700;


// Read Digital Inputs
void readdigital() {

    // Read input pins into var array
    for(int i=1; i<=DIGITAL_INPUT_PINCOUNT; i++){
        Button_State[i] = digitalRead(DI_Raw[i]);
    }
    
    for(int i=1; i<=DIGITAL_INPUT_PINCOUNT; i++) {
        if ((Button_State[i] == 0) && (Button_State_Old[i] == 0) && (Button_State_Falling[i] == 0)){
            Button_State_Falling[i] = 1;
            Button_Pulse[i] = 1;
        } else if ((Button_State[i] == 1) && (Button_State_Old[i] == 1)) {
            Button_State_Falling[i] = 0;
            Button_Pulse[i] = 0;
        }
    } 
    
    for(int i=1; i<=DIGITAL_INPUT_PINCOUNT; i++){ 
        Button_State_Old[i] = Button_State[i];
    }
   
    // Thr Switch Handling
    if ( Button_State[THR_SWITCH_NUM] ){
        digitalWrite (CH8_SWITCH_LED_PIN, LOW);
        timer2_running = false;
    } else {                                                                                    
        digitalWrite (CH8_SWITCH_LED_PIN, HIGH);
        if ( ModeDispSet != TIMER_ADJUST ){
            timer2_running = true;
        } else {
            timer2_running = false;
        }
    }
   
    // Lo/Hi Rates Switch
    if (Button_State[AUX1_SWITCH_NUM] == 0) {                                                         // AUX1 switch is up
        RateMult = HIGH_RATE_MULTIPLIER;
    } else {
        RateMult = LOW_RATE_MULTIPLIER;
    }
   
    // Ch7 Switch	
    if (Button_State[CH7_SWITCH_NUM] == 1) {                                                           // Ch7 switch is down
        Auxsw_uS = PWM_MIN;
        digitalWrite (CH7_SWITCH_LED_PIN, LOW);
    } else {
        Auxsw_uS = PWM_MAX;
        digitalWrite (CH7_SWITCH_LED_PIN, HIGH);
    }
    
    // Ch8 Handling
    
    if ( active_model.thr_switch_mode == THR_ON_CH8_HOLD ){
        if ( Button_State[THR_SWITCH_NUM] ){                                                        // Thr switch is down
            AI_Auxpot2 = PWM_MIN;
        } else {                                                                                    // Thr switch is up
            AI_Auxpot2 = map(AI_Val[5], CH8_MIN, CH8_MAX, PWM_MIN, PWM_MAX);                        // Aux pot 2
        }
    } else {
        AI_Auxpot2 = map(AI_Val[5], CH8_MIN, CH8_MAX, PWM_MIN, PWM_MAX);
    }
}

void control_flight_mode(){

    for(int i=1; i<=6; i++){
        FMB_State[i] = digitalRead(Flight_Mode_Inputs[i]);
    }
    for(int i=1; i<=6; i++) {
        if ((FMB_State[i] == 0) && (FMB_State_Old[i] == 0) && (FMB_State_Falling[i] == 0)){
            FMB_State_Falling[i] = 1;
            if (Active_Flight_Mode != i){
                Old_Flight_Mode = Active_Flight_Mode;
                Active_Flight_Mode = i;
                buzzeractivate = 1;
                digitalWrite (Flight_Mode_LED[Old_Flight_Mode], LOW);
                digitalWrite (Flight_Mode_LED[Active_Flight_Mode], HIGH);
                Active_Flight_Mode_PWM = Flight_Mode_PWM[Active_Flight_Mode];
            }
        } else if ((FMB_State[i] == 1) && (FMB_State_Old[i] == 1)) {
            FMB_State_Falling[i] = 0;
        }
    }
    for(int i=1; i<=6; i++){ 
        FMB_State_Old[i] = FMB_State[i];
    }
}


// Read Analogue Inputs
void readanalogue() {

    // Read all input pins into AI var array 1
    for(byte i=0; i<ANALOG_INPUT_PINCOUNT; i++) {  
        AI_Val[i] = analogRead(AI_Pin[i]);
    } 
 
    // Read first 4 inputs again for 5 sample averaging (AEL/ELE/THR/RUD) 
    for(byte i=0; i<3; i++) {  
        AI_Val2[i] = analogRead(AI_Pin[i]);  // AI var array 2
    }
    for(byte i=0; i<3; i++) {  
        AI_Val3[i] = analogRead(AI_Pin[i]);  // AI var array 3
    }
    for(byte i=0; i<3; i++) {  
        AI_Val4[i] = analogRead(AI_Pin[i]);  // AI var array 4
    }
    for(byte i=0; i<3; i++) {  
        AI_Val5[i] = analogRead(AI_Pin[i]);  // AI var array 5
    }
    for(byte i=0; i<3; i++) {
        AI_Val[i] = (AI_Val[i] + AI_Val2[i] + AI_Val3[i] + AI_Val4[i] + AI_Val5[i]) / 5;  // 5 sample averages
    }
   
    // Incorporate Rate Multiplier then scale inputs to produce PPM values
    
    Min_Limit[0] = (PWM_MID - (RateMult * (PWM_MID - PWM_MIN - active_model.EP_low[0])));     
    Max_Limit[0] = (PWM_MID + (RateMult * (PWM_MAX - PWM_MID + active_model.EP_high[0])));
    
    Min_Limit[1] = (PWM_MID - (RateMult * (PWM_MID - PWM_MIN - active_model.EP_low[1])));    
    Max_Limit[1] = (PWM_MID + (RateMult * (PWM_MAX - PWM_MID + active_model.EP_high[1])));
    
    Min_Limit[2] = (PWM_MIN + active_model.EP_low[2]);                  // Throttle does not get dual rates  
    Max_Limit[2] = (PWM_MAX + active_model.EP_high[2]);
    
    Min_Limit[3] = (PWM_MID - (RateMult * (PWM_MID - PWM_MIN - active_model.EP_low[3])));     
    Max_Limit[3] = (PWM_MID + (RateMult * (PWM_MAX - PWM_MID + active_model.EP_high[3])));
    
    if (AI_Val[0] < ROLL_MID) { AI_Aeler = map(AI_Val[0], ROLL_MIN, ROLL_MID-1, Min_Limit[0], PWM_MID) + active_model.trim[0]; }                       // Roll  
    if (AI_Val[0] >= ROLL_MID) { AI_Aeler = map(AI_Val[0], ROLL_MID, ROLL_MAX, PWM_MID + 1, Max_Limit[0]) + active_model.trim[0]; }                    // Roll
    
    if (AI_Val[1] < PITCH_MID) { AI_Eleva = map(AI_Val[1], PITCH_MIN, PITCH_MID-1, Min_Limit[1], PWM_MID) + active_model.trim[1]; }                 // Pitch 
    if (AI_Val[1] >= PITCH_MID) { AI_Eleva = map(AI_Val[1], PITCH_MID, PITCH_MAX, PWM_MID + 1, Max_Limit[1]) + active_model.trim[1]; }              // Pitch 
  
    if (AI_Val[2] < THROTTLE_MID) { AI_Throt = map(AI_Val[2], THROTTLE_MIN, THROTTLE_MID-1, Min_Limit[2], PWM_MID) + active_model.trim[2]; }        // Throttle 
    if (AI_Val[2] >= THROTTLE_MID) { AI_Throt = map(AI_Val[2], THROTTLE_MID, THROTTLE_MAX, PWM_MID + 1, Max_Limit[2]) + active_model.trim[2]; }     // Throttle 
  
    if (AI_Val[3] < YAW_MID) { AI_Rudde = map(AI_Val[3], YAW_MIN, YAW_MID-1, Min_Limit[3], PWM_MID) + active_model.trim[3]; }                       // Yaw 
    if (AI_Val[3] >= YAW_MID) { AI_Rudde = map(AI_Val[3], YAW_MID, YAW_MAX, PWM_MID + 1, Max_Limit[3]) + active_model.trim[3]; }                    // Yaw  
   
    if ( active_model.thr_switch_mode == THR_STICK_HOLD){                                       // If throttle switch mode is on Throttle Stick Hold
        if ( Button_State[THR_SWITCH_NUM] ){                                                    // and if throttle switch is down
            AI_Throt = Min_Limit[2];                                                            // hold throttle down so that throttle is inactive
        } else {                                                                                // If throttle switch is up
            AI_Throt = constrain (AI_Throt, Min_Limit[2] + THR_SAFETY_OFFSET, Max_Limit[2]);    // Hold throttle up from bottom so that cannot "Arm" the APM
        }                                                                                       // Nor can you shut down the throttle mid-flight accidentally
    }
            
    AI_Auxpot1 = map(AI_Val[4], CH6_MIN, CH6_MAX, PWM_MIN, PWM_MAX);                // Map Aux Pot 1    
}

// Check limits & set outputs
void checklimitsmodessetouputs() {
 
    // Exponential Aelerons
    if  (ToDo) {
        if (AI_Val[0] < ROLL_MID ){
            AI_AelerF = AI_Aeler - PWM_MID;  // zero
            AI_AelerF = ((((AI_AelerF*-1)/10) * ((AI_AelerF*-1)/10))) * -1;  // low side calc
            AI_AelerF = AI_AelerF * .3;  // reduce gain
            AI_Aeler = AI_AelerF + PWM_MID;
        }
        if (AI_Val[0] >= ROLL_MID ){
            AI_AelerF = AI_Aeler - PWM_MID;  // zero
            AI_AelerF = (AI_AelerF/10) * (AI_AelerF/10);  // high side calc
            AI_AelerF = AI_AelerF * .3;  // reduce gain
            AI_Aeler = AI_AelerF + PWM_MID;
        }
    }   

    // Exponential Elevators
    if  (ToDo) {
        if (AI_Val[1] < PITCH_MID ){
            AI_ElevaF = AI_Eleva - PWM_MID;  // zero
            AI_ElevaF = ((((AI_ElevaF*-1)/10) * ((AI_ElevaF*-1)/10))) * -1;  // low side calc
            AI_ElevaF = AI_ElevaF * .3;  // reduce gain
            AI_Eleva = AI_ElevaF + PWM_MID;
        }
        if (AI_Val[1] >= PITCH_MID ){
            AI_ElevaF = AI_Eleva - PWM_MID;  // zero
            AI_ElevaF = (AI_ElevaF/10) * (AI_ElevaF/10);  // high side calc
            AI_ElevaF = AI_ElevaF * .3;  // reduce gain
            AI_Eleva = AI_ElevaF + PWM_MID;
        }
    }

    // Exponential Rudder
    if (ToDo) {
        if (AI_Val[3] < YAW_MID ){
            AI_RuddeF = AI_Rudde - PWM_MID;  // zero
            AI_RuddeF = ((((AI_RuddeF*-1)/10) * ((AI_RuddeF*-1)/10))) * -1;  // low side calc
            AI_RuddeF = AI_RuddeF * .3;  // reduce gain
            AI_Rudde = AI_RuddeF + PWM_MID;
        }
        if (AI_Val[3] >= YAW_MID ){
            AI_RuddeF = AI_Rudde - PWM_MID;  // zero
            AI_RuddeF = (AI_RuddeF/10) * (AI_RuddeF/10);  // high side calc
            AI_RuddeF = AI_RuddeF * .3;  // reduce gain
            AI_Rudde = AI_RuddeF + PWM_MID;
        }
    }
     
    // Load PPM channel array with final channel values
    PPM_buffer[0] = constrain (AI_Aeler, PWM_HARD_MIN, PWM_HARD_MAX);                   // Channel 1 Roll
    PPM_buffer[1] = constrain (AI_Eleva, PWM_HARD_MIN, PWM_HARD_MAX);                   // Channel 2 Pitch
    PPM_buffer[2] = constrain (AI_Throt, PWM_HARD_MIN, PWM_HARD_MAX);                   // Channel 3 Throttle
    PPM_buffer[3] = constrain (AI_Rudde, PWM_HARD_MIN, PWM_HARD_MAX);                   // Channel 4 Yaw
    PPM_buffer[4] = constrain (Active_Flight_Mode_PWM, PWM_HARD_MIN, PWM_HARD_MAX);     // Channel 5 Flight Mode
    PPM_buffer[5] = constrain (AI_Auxpot1, PWM_HARD_MIN, PWM_HARD_MAX);                 // Channel 6 Ch6 Tuning
    PPM_buffer[6] = constrain (Auxsw_uS, PWM_HARD_MIN, PWM_HARD_MAX);                   // Channel 7 Ch7 Switch
    PPM_buffer[7] = constrain (AI_Auxpot2, PWM_HARD_MIN, PWM_HARD_MAX);                 // Channel 8 Ch8 Aux Knob

    cli();
    PPM_array[ 0 ] = PPM_buffer[ 0 ];
    PPM_array[ 1 ] = PPM_buffer[ 1 ];
    PPM_array[ 2 ] = PPM_buffer[ 2 ];
    PPM_array[ 3 ] = PPM_buffer[ 3 ];
    PPM_array[ 4 ] = PPM_buffer[ 4 ];
    PPM_array[ 5 ] = PPM_buffer[ 5 ];
    PPM_array[ 6 ] = PPM_buffer[ 6 ];
    PPM_array[ 7 ] = PPM_buffer[ 7 ];
    sei();
}
