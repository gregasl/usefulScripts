"""Diagnostic: subscribe to UAT + prod-named channels on cacheuat for 12s."""
import time
from collections import Counter
import orjson
from ASL.utils.asl_redis import ASLRedis

r = ASLRedis(host="cacheuat")
ps = r.pubsub(ignore_subscribe_messages=True)
channels = [
    "ION:ION_MARKET_DATA_UAT",
    "ION:ION_INSTRUMENT_DATA_UAT",
    "ION:ION_CM_TICKER_DATA_UAT",
    "ION:ION_CM_LOGIN_DATA_UAT",
    "HEARTBEAT:ION:MARKET_DATA_UAT",
    "ION:ION_MARKET_DATA",
    "ION:ION_INSTRUMENT_DATA",
    "ION:ION_CM_TICKER_DATA",
    "ION:ION_CM_LOGIN_DATA",
    "HEARTBEAT:ION:MARKET_DATA",
]
ps.subscribe(*channels)
print("SUBSCRIBED to", len(channels), "channels for 12s")

counts = Counter()
samples = {}
deadline = time.time() + 12.0
while time.time() < deadline:
    msg = ps.get_message(timeout=0.5)
    if msg is None:
        continue
    ch = msg["channel"]
    if isinstance(ch, bytes):
        ch = ch.decode()
    counts[ch] += 1
    if ch not in samples:
        data = msg["data"]
        if isinstance(data, bytes):
            try:
                samples[ch] = orjson.loads(data)
            except Exception:
                samples[ch] = data[:200]
        else:
            samples[ch] = data

print("---COUNTS---")
if not counts:
    print("(no traffic on any of the 10 subscribed channels)")
for ch, n in counts.most_common():
    print(f"  {ch}: {n}")

print("---SAMPLES (first message per channel)---")
for ch, s in samples.items():
    print(f"\n[{ch}]")
    if isinstance(s, dict):
        for k, v in list(s.items())[:14]:
            sval = str(v)
            if len(sval) > 80:
                sval = sval[:77] + "..."
            print(f"  {k} = {sval}")
    else:
        print(f"  {s}")
ps.close()
