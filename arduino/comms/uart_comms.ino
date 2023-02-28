/*
 * Hello World!
 *
 * This is the Hello World! for Arduino. 
 * It shows how to send data to the computer
 */


void setup()                    // run once, when the sketch starts
{
  pinMode(1, INPUT);           //by setting the TX pin as an INPUT, we override the Arduino's UART, and it goes directly to FTDI
}

void loop()                       // run over and over again
{
}