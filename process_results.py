import serial
import sys
from tqdm import tqdm
from math import ceil
import sys

serialPort = serial.Serial(
    port='COM10',
    baudrate=115200,
    bytesize=8,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_ONE
)

# 1 million bits approx eq 128 Kib = 131072 bytes
desiredBytes = 1310720 if ((len(sys.argv) > 2) and (sys.argv[2] == 'full')) else 131072
chunkSize = 512

filename = sys.argv[1] + ".bin"

fp = open(filename, 'wb')

for i in tqdm(range(ceil(desiredBytes/chunkSize))):
    # Wait until there is data waiting in the serial buffer
    serialBytes = serialPort.read(chunkSize)
    assert(len(serialBytes) == chunkSize)

    # Print the contents of the serial data
    fp.write(serialBytes)

fp.close()
print('Done collecting data!')

ones_count = 0
data_length = 0

with open(filename, 'rb') as f:
    data = f.read()

    data_length = len(data)*8

    for x in range(len(data)):
        for z in range(8):
            if ((data[x] >> z) & 1) == 1:
                ones_count = ones_count + 1

ones_count_percent = (ones_count/data_length)*100

if ((len(sys.argv) > 2) and (sys.argv[2] == 'full')):
    with open('bias-tracker.data', 'a') as f:
        f.write(sys.argv[1] + ": " + str(ones_count_percent) + "\n")
 


