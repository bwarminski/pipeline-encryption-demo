import datetime
import json

import boto3
import pg8000
from chalice import Chalice, Rate
from chalicelib.loader import Loader, LoaderConfig

app = Chalice(app_name='analytics')
app.debug = True
sqs = boto3.client('sqs')

config = LoaderConfig('demo-cluster', 'demo-cluster.cfesvzwemygr.us-east-1.redshift.amazonaws.com', 5439, 'loader', 'dev',
                      'spark-retail.sandbox', '1g/json', 'bwarminski.redshift.ingest', '1g',
                      'arn:aws:iam::645643289692:role/redshift-s3', 'us-east-1')

loader = Loader(config, pg8000, boto3.client('redshift'), boto3.client('s3'))
MAX_DATE = datetime.date(2003,1,8)

@app.schedule(Rate(1, unit=Rate.MINUTES))
def create_data(event):
    app.log.info("Getting next date")
    date = loader.next_date()
    app.log.info("Next date is %s", date)
    files = set()
    while date <= MAX_DATE and len(files) == 0:
        app.log.info("Finding missing files for %s", date)
        files = loader.missing_files(date)
        if len(files) == 0:
            app.log.info("No files found")
            date = date + datetime.timedelta(days=1)

    if len(files) > 0:
        app.log.info("Creating files for %s - %s", date, files)
        loader.create_files(date, files)


@app.on_sqs_message(queue='new-redshift-files')
def load(event):
    app.log.info("Received message")
    for record in event:
        body_json = json.loads(record.body)
        for json_record in body_json.get('Records', []):
            if 's3' in json_record and 'object' in json_record['s3']:
                key = json_record['s3']['object']['key']
                date = datetime.datetime.strptime(key.split('/')[-2], "%Y-%m-%d").date()
                app.log.info("loading %s", key)
                loader.load_file(date,key)



# The view function above will return {"hello": "world"}
# whenever you make an HTTP GET request to '/'.
#
# Here are a few more examples:
#
# @app.route('/hello/{name}')
# def hello_name(name):
#    # '/hello/james' -> {"hello": "james"}
#    return {'hello': name}
#
# @app.route('/users', methods=['POST'])
# def create_user():
#     # This is the JSON body the user sent in their POST request.
#     user_as_json = app.current_request.json_body
#     # We'll echo the json body back to the user in a 'user' key.
#     return {'user': user_as_json}
#
# See the README documentation for more examples.
#
