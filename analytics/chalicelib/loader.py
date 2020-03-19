import datetime
import itertools
import re

from collections import namedtuple

LoaderConfig = namedtuple('LoaderConfig', 'cluster_id cluster_host cluster_port username database source_bucket '
                                          'source_prefix dest_bucket dest_prefix cluster_iam_role aws_region')

class Loader:
    def __init__(self, config: LoaderConfig, db, redshift, s3):
        self.config = config
        self.db = db
        self.redshift = redshift
        self.s3 = s3

    def __get_conn(self):
        resp = self.redshift.get_cluster_credentials(DbUser=self.config.username,
                                                     ClusterIdentifier=self.config.cluster_id)
        return self.db.connect(resp['DbUser'],
                               host=self.config.cluster_host,
                               port=self.config.cluster_port,
                               password=resp['DbPassword'],
                               database=self.config.database,
                               ssl=True)
    def next_date(self):
        conn = self.__get_conn()
        with conn:
            cur = conn.cursor()
            cur.execute("select max(filedate) from public.sales_files_loaded")
            max_date = cur.fetchone()[0]

            if max_date is None:
                return datetime.date(1998,1,1)
            else:
                return max_date

    def missing_files(self, date):
        paginator = self.s3.get_paginator('list_objects_v2')
        pages = paginator.paginate(
            Bucket=self.config.source_bucket,
            Delimiter='/',
            Prefix="{}/{}/".format(self.config.source_prefix, date.strftime('sold_date=%Y-%m-%d')),
            FetchOwner=False
        )

        def keys(page):
            return [x['Key'] for x in page.get('Contents', []) if x['Key'].endswith('.json.gz')]

        def filename(key):
            return key.split('/')[-1]

        source_files = set(map(filename, itertools.chain.from_iterable(map(keys, pages))))

        pages = paginator.paginate(
            Bucket=self.config.dest_bucket,
            Delimiter='/',
            Prefix="{}/{}/".format(self.config.dest_prefix, date.strftime('%Y-%m-%d')),
            FetchOwner=False
        )

        dest_files = set(map(filename, itertools.chain.from_iterable(map(keys, pages))))
        return source_files - dest_files

    def create_files(self, date, files):
        for file in files:
            copy_source = "{}/{}/{}/{}".format(self.config.source_bucket,
                                               self.config.source_prefix,
                                               date.strftime('sold_date=%Y-%m-%d'),file)
            dest_key = "{}/{}/{}".format(self.config.dest_prefix, date.strftime('%Y-%m-%d'), file)
            self.s3.copy_object(
                Bucket=self.config.dest_bucket,
                Key=dest_key,
                CopySource=copy_source
            )

    def load_file(self, date, key):
        if not re.fullmatch('^[a-zA-Z0-9\-.\\\/]+$', key):  # pg8000 prepares all statements and Redshift doesn't like it
            raise Exception('invalid key')
        conn = self.__get_conn()
        with conn:
            cur = conn.cursor()
            cur.execute('insert into public.sales_files_loaded (filedate, filename) values (%s, %s)', (date,key))
            cur.execute('select count(*) from public.sales_files_loaded where filedate=%s and filename=%s', (date,key))
            if cur.fetchone()[0] != 1:
                return
            s3_arn = 's3://{}/{}'.format(self.config.dest_bucket,key)
            cur.execute("""
                copy public.sales
                    from '{}'
                    credentials 'aws_iam_role={}'
                    gzip
                    region '{}'
                    format as json 'auto'
                    dateformat 'auto'
            """.format(s3_arn, self.config.cluster_iam_role, self.config.aws_region))
            conn.commit()
