import apache_beam as beam
from apache_beam.runners.portability.fn_api_runner import fn_runner
import re
import os
import time

LOCAL_DIR = '/tmp/htmlfiles'

def read_and_extract_bigrams(filename):
    filepath = os.path.join(LOCAL_DIR, filename)
    with open(filepath, 'r', errors='ignore') as f:
        content = f.read()
    text = re.sub(r'<[^>]+>', ' ', content)
    words = re.findall(r'[a-z]+', text.lower())
    for i in range(len(words) - 1):
        yield (f"{words[i]} {words[i+1]}", 1)

def run():
    filenames = [f for f in os.listdir(LOCAL_DIR) if f.endswith('.html')]
    print(f"Found {len(filenames)} files")

    start = time.time()

    runner = fn_runner.FnApiRunner()
    with beam.Pipeline(runner=runner) as p:
        (
            p
            | 'CreateFiles' >> beam.Create(filenames)
            | 'ExtractBigrams' >> beam.FlatMap(read_and_extract_bigrams)
            | 'SumBigrams' >> beam.CombinePerKey(sum)
            | 'TopBigrams' >> beam.combiners.Top.Of(5, key=lambda x: x[1])
            | 'PrintBigrams' >> beam.Map(
                lambda x: print("\nTop 5 Word Bigrams:\n" + "\n".join(
                    f"  '{b}': {c}" for b, c in x
                ))
            )
        )

    elapsed = time.time() - start
    print(f"\nTotal pipeline runtime: {elapsed:.2f} seconds")

if __name__ == '__main__':
    run()
