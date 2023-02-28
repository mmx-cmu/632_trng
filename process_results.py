import serial
from tqdm import tqdm
from math import ceil
import sys

serialPort = serial.Serial(
    port='COM9',
    baudrate=115200,
    bytesize=8,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_ONE
)

# 1 million bits approx eq 128 Kib = 131072 bytes
desiredBytes = 1310720 if ((len(sys.argv) > 1) and (sys.argv[1] == 'full')) else 131072
chunkSize = 512

fp = open('data.bin', 'wb')

for i in tqdm(range(ceil(desiredBytes/chunkSize))):
    # Wait until there is data waiting in the serial buffer
    serialBytes = serialPort.read(chunkSize)
    assert(len(serialBytes) == chunkSize)

    # Print the contents of the serial data
    fp.write(serialBytes)

fp.close()
print('done!')
