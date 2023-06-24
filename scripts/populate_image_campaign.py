import argparse
import sqlite3
import shutil
import os

parser = argparse.ArgumentParser(description='''
Objects in all databases seem to have the correct value of "campaign" key
in table "properties". Table images has field "name", which also is supposed
to contain the campaign id. However, images.name seems to be not populated
correctly in many databases. This script fixes that for one database.

Usage:
  Run this once for the input_db_file and for every previous campaign.
''')
parser.add_argument('-i', '--input_db_file', required=True)
parser.add_argument('--campaign_db_file',
                    required=True,
                    help='Reference db of a campaign.')
parser.add_argument('--campaign_id',
                    required=True,
                    type=int,
                    help='Campaign id to set.')
parser.add_argument('-o', '--output_db_file')
args = parser.parse_args()

assert os.path.exists(args.input_db_file)

conn = sqlite3.connect('file:%s?mode=ro' % args.campaign_db_file, uri=True)
c = conn.cursor()
c.execute('SELECT imagefile FROM images')
ref_imagefiles = c.fetchall()
conn.close()

if args.output_db_file is not None:
    if args.output_db_file != args.input_db_file:
        shutil.copyfile(args.input_db_file, args.output_db_file)
    conn = sqlite3.connect(args.output_db_file)
else:
    conn = sqlite3.connect('file:%s?mode=ro' % args.input_db_file, uri=True)
c = conn.cursor()

for imagefile, in ref_imagefiles:
    if args.output_db_file is not None:
        c.execute('UPDATE images SET name=? WHERE imagefile=?',
                  (args.campaign_id, imagefile))

if args.output_db_file is not None:
    conn.commit()
conn.close()

print('Done.')
