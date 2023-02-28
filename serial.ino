/*
 * Hello World!
 *
 * This is the Hello World! for Arduino. 
 * It shows how to send data to the computer
 */


void setup()                    // run once, when the sketch starts
{
  pinMode(0, INPUT);      // set pin as input
  pinMode(1, INPUT);
  // Serial.begin(115200);           // set up Serial library at 9600 bps
  // Serial.println("Hello world!");  // prints hello with ending line break 
}

void loop()                       // run over and over again
{
  // if(Serial.available()) {
  //     char data_rcvd = Serial.read();   // read one byte from serial buffer and save to data_rcvd
  //     Serial.println(data_rcvd, BIN);
  // }
}
