import sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
print("LINE 1")
sys.stdout.flush()
f = open(os.path.join(HERE, "__probe2.txt"), "w")
f.write("PROBE OK\n")
f.close()
print("LINE 2 - wrote probe")
sys.stdout.flush()
