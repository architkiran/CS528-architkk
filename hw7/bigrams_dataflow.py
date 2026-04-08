import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions, GoogleCloudOptions, StandardOptions, SetupOptions
import re
import time
import subprocess

BUCKET = 'bu-cs528-architkk'
PROJECT = 'utopian-planet-485618-b3'
REGION = 'us-east1'
SA = 'hw7-dataflow-sa@utopian-planet-485618-b3.iam.gserviceaccount.com'

def extract_bigrams_gcs(filename):
    from google.cloud import storage
    import re
    fname = filename.strip().split('/')[-1]
    client = storage.Client()
    blob = client.bucket(BUCKET).blob(fname)
    content = blob.download_as_text()
    text = re.sub(r'<[^>]+>', ' ', content)
    words = re.findall(r'[a-z]+', text.lower())
    for i in range(len(words) - 1):
        yield (f"{words[i]} {words[i+1]}", 1)

def run():
    with open('/home/architkk/filelist.txt') as f:
        filenames = [l.strip() for l in f if l.strip().endswith('.html')]
    print(f"Found {len(filenames)} files, submitting to Dataflow...")

    options = PipelineOptions()
    gcloud_opts = options.view_as(GoogleCloudOptions)
    gcloud_opts.project = PROJECT
    gcloud_opts.region = 'us-east4'
    gcloud_opts.temp_location = f'gs://{BUCKET}/tmp/'
    gcloud_opts.staging_location = f'gs://{BUCKET}/staging/'
    gcloud_opts.job_name = 'hw7-bigrams-df2'
    gcloud_opts.service_account_email = SA
    options.view_as(StandardOptions).runner = 'DataflowRunner'
    options.view_as(SetupOptions).save_main_session = True

    start = time.time()

    with beam.Pipeline(options=options) as p:
        (
            p
            | 'CreateFiles' >> beam.Create(filenames)
            | 'ExtractBigrams' >> beam.FlatMap(extract_bigrams_gcs)
            | 'SumBigrams' >> beam.CombinePerKey(sum)
            | 'TopBigrams' >> beam.combiners.Top.Of(5, key=lambda x: x[1])
            | 'WriteBigrams' >> beam.io.WriteToText(f'gs://{BUCKET}/hw7_output/top_bigrams')
        )

    elapsed = time.time() - start
    print(f"\nDataflow job runtime: {elapsed:.2f} seconds")

    result = subprocess.run(
        ['gsutil', 'cat', f'gs://{BUCKET}/hw7_output/top_bigrams-00000-of-00001'],
        capture_output=True, text=True)
    print(f"\nTop 5 Bigrams:\n{result.stdout}")

if __name__ == '__main__':
    run()
