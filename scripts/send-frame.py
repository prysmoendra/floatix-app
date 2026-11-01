import json, struct, sys, time
for m in sys.argv[1:-1]:
    b = m.encode(); sys.stdout.buffer.write(struct.pack('<I', len(b)) + b); sys.stdout.flush(); time.sleep(0.5)
time.sleep(float(sys.argv[-1]))
