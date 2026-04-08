import apache_beam as beam
from apache_beam.runners.portability.fn_api_runner import fn_runner
import re
import os
import time

LOCAL_DIR = '/tmp/htmlfiles'

def read_and_extract_links(filename):
    filepath = os.path.join(LOCAL_DIR, filename)
    with open(filepath, 'r', errors='ignore') as f:
        content = f.read()
    targets = re.findall(r'<a\s+HREF="([^"]+)"', content, re.IGNORECASE)
    return (filename, targets)

def emit_outgoing(element):
    src, targets = element
    yield (src, len(targets))

def emit_incoming(element):
    src, targets = element
    for tgt in targets:
        yield (tgt, 1)

def run():
    filenames = [f for f in os.listdir(LOCAL_DIR) if f.endswith('.html')]
    print(f"Found {len(filenames)} files")

    start = time.time()

    runner = fn_runner.FnApiRunner()
    with beam.Pipeline(runner=runner) as p:
        links = (
            p
            | 'CreateFiles' >> beam.Create(filenames)
            | 'ReadAndExtract' >> beam.Map(read_and_extract_links)
        )

        (
            links
            | 'OutgoingCount' >> beam.FlatMap(emit_outgoing)
            | 'TopOutgoing' >> beam.combiners.Top.Of(5, key=lambda x: x[1])
            | 'PrintOutgoing' >> beam.Map(
                lambda x: print("\nTop 5 Files by Outgoing Links:\n" + "\n".join(
                    f"  {f}: {c} outgoing links" for f, c in x
                ))
            )
        )

        (
            links
            | 'IncomingPairs' >> beam.FlatMap(emit_incoming)
            | 'SumIncoming' >> beam.CombinePerKey(sum)
            | 'TopIncoming' >> beam.combiners.Top.Of(5, key=lambda x: x[1])
            | 'PrintIncoming' >> beam.Map(
                lambda x: print("\nTop 5 Files by Incoming Links:\n" + "\n".join(
                    f"  {f}: {c} incoming links" for f, c in x
                ))
            )
        )

    elapsed = time.time() - start
    print(f"\nTotal pipeline runtime: {elapsed:.2f} seconds")

if __name__ == '__main__':
    run()
