"""Histogram class file major versions in a JAR. Major 52 = Java 8."""
import sys, zipfile
from collections import Counter, defaultdict

JAR = "marketDataSubscriber.jar"
JAVA_MAJOR = {45:"1.1",46:"1.2",47:"1.3",48:"1.4",49:"5",50:"6",51:"7",52:"8",53:"9",54:"10",55:"11",56:"12",57:"13",58:"14",59:"15",60:"16",61:"17",62:"18",63:"19",64:"20",65:"21"}

counts = Counter()
samples = defaultdict(list)
with zipfile.ZipFile(JAR) as z:
    for name in z.namelist():
        if not name.endswith(".class"):
            continue
        with z.open(name) as f:
            head = f.read(8)
        if len(head) < 8 or head[:4] != b"\xca\xfe\xba\xbe":
            continue
        major = int.from_bytes(head[6:8], "big")
        counts[major] += 1
        if len(samples[major]) < 3:
            samples[major].append(name)

print(f"{JAR}: {sum(counts.values())} class files\n")
for major, n in sorted(counts.items()):
    label = JAVA_MAJOR.get(major, f"unknown({major})")
    print(f"  major={major} (Java {label}): {n} classes")
    for s in samples[major]:
        print(f"      e.g. {s}")
