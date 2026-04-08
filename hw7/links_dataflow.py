import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions, GoogleCloudOptions, StandardOptions, SetupOptions, WorkerOptions
import re, time, subprocess

BUCKET = 'bu-cs528-architkk'
PROJECT = 'utopian-planet-485618-b3'
SA = 'hw7-dataflow-sa@utopian-planet-485618-b3.iam.gserviceaccount.com'

def extract_links_gcs(filename):
    from google.cloud import storage
    import re
    fname = filename.strip().split('/')[-1]
    client = storage.Client()
    content = client.bucket(BUCKET).blob(fname).download_as_text()
    targets = re.findall(r'<a\s+HREF="([^"]+)"', content, re.IGNORECASE)
    return (fname, targets)

def emit_outgoing(element):
    src, targets = element
    yield (src, len(targets))

def emit_incoming(element):
    src, targets = element
    for tgt in targets:
        yield (tgt, 1)

def run():
    with open('/home/architkk/filelist.txt') as f:
        filenames = [l.strip() for l in f if l.strip().endswith('.html')]
    print(f"Found {len(filenames)} files, submitting to Dataflow...")

    options = PipelineOptions()
    gcloud_opts = options.view_as(GoogleCloudOptions)
    gcloud_opts.project = PROJECT
    gcloud_opts.region = 'us-east1'
    gcloud_opts.temp_location = f'gs://{BUCKET}/tmp/'
    gcloud_opts.staging_location = f'gs://{BUCKET}/staging/'
    gcloud_opts.job_name = 'hw7-links-df6'
    gcloud_opts.service_account_email = SA
    options.view_as(StandardOptions).runner = 'DataflowRunner'
    options.view_as(SetupOptions).save_main_session = True
    worker_opts = options.view_as(WorkerOptions)
    worker_opts.machine_type = 'e2-standard-2'
    worker_opts.num_workers = 2
    worker_opts.max_num_workers = 4

    start = time.time()
    with beam.Pipeline(options=options) as p:
        links = (
            p
            | 'CreateFiles' >> beam.Create(filenames)
            | 'ReadAndExtract' >> beam.Map(extract_links_gcs)
        )
        (links
            | 'OutgoingCount' >> beam.FlatMap(emit_outgoing)
            | 'TopOutgoing' >> beam.combiners.Top.Of(5, key=lambda x: x[1])
            | 'WriteOutgoing' >> beam.io.WriteToText(f'gs://{BUCKET}/hw7_output/top_outgoing')
        )
        (links
            | 'IncomingPairs' >> beam.FlatMap(emit_incoming)
            | 'SumIncoming' >> beam.CombinePerKey(sum)
            | 'TopIncoming' >> beam.combiners.Top.Of(5, key=lambda x: x[1])
            | 'WriteIncoming' >> beam.io.WriteToText(f'gs://{BUCKET}/hw7_output/top_incoming')
        )

    elapsed = time.time() - start
    print(f"\nDataflow job runtime: {elapsed:.2f} seconds")
    for label, path in [('Outgoing', 'top_outgoing'), ('Incoming', 'top_incoming')]:
        r = subprocess.run(['gsutil', 'cat', f'gs://{BUCKET}/hw7_output/{path}-00000-of-00001'],
                          capture_output=True, text=True)
        print(f"\nTop 5 by {label} Links:\n{r.stdout}")

if __name__ == '__main__':
    run()
