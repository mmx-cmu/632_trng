from PIL import Image
from math import sqrt, ceil

with open('data.bin', 'rb') as f:
    data = f.read()
    dims = ceil(sqrt(len(data)))
    dims_bw = ceil(sqrt(len(data) * 8))

    im_grayscale = Image.new('L', [dims, dims], 255)
    im_bw = Image.new('RGB', [dims_bw, dims_bw], 255)
    im_data = im_bw.load()

    im_grayscale.putdata(data)
    im_grayscale.save('data_grayscale.png')

    for x in range(len(data)):
        for z in range(8):
            idx = x * 8 + z
            a = idx//dims_bw
            b = idx % dims_bw
            has_data = 255 if ((data[x] >> z) & 1) else 0
            im_data[a,b] = (0, has_data, 0)

    im_bw.save('data_bw.png')

