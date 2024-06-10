import sys
import argparse
import pyftdi.serialext
import time

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-r', '--read', nargs=2, help='Read address')
    parser.add_argument('-w', '--write', nargs=2, help='Write address and data')
    args = parser.parse_args()
    brate = 230400
    url = 'ftdi://ftdi:232:AQ00RVZA/1'
    port = pyftdi.serialext.serial_for_url(url, baudrate=brate, bytesize=8, stopbits=1, parity='N', xonxoff=False, rtscts=False)
    if args.read:
        addr, nb = args.read
        print(f"Reading from {addr}")
        data = port.read(int(addr,nb))
        print(f"Data: {data}")
    if args.write:
        addr, data = args.write
        print(f"Writing {data} to {addr}")
        data_bytes = data.encode()
        port.write(data_bytes)
    port.close()
if __name__ == "__main__":
    main()