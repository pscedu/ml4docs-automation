#!/bin/bash

'''
This file reads and analyzes .out files created by detection training scripts.
The result of the analysis is how different hyperparameters perform.
The output of this script goes to google sheets.
'''

import os, sys
import re
import logging
import numpy as np
import argparse
import pandas as pd
import matplotlib.pyplot as plt


def get_parser():
    parser = argparse.ArgumentParser(
        description="Postprocess results of training.")

    parser.add_argument("--experiments_path", required=True)
    parser.add_argument("--campaign", type=int, required=True)
    parser.add_argument("--set", type=int, required=True)
    parser.add_argument("--run", type=int, required=True)
    parser.add_argument("--ignore_splits",
                        nargs='*',
                        default=['full'],
                        help='The splits with this name are not imported.')
    parser.add_argument("--results_root_dir",
                        default='/ocean/projects/hum180001p/shared/detection')
    parser.add_argument(
        "--IoU",
        default="0.50 ",
        help="Will look for this 'IoU' in .out files. Default: 0.50")
    parser.add_argument(
        "--area",
        default="all",
        help="Will look for this 'area' in .out files. Default: all")
    parser.add_argument(
        "--logging_level",
        type=int,
        choices=[10, 20, 30, 40],
        default=20,
        help="Set logging level. 10: debug, 20: info, 30: warning, 40: error.")
    return parser


def postprocess_one_run(results_dir, hyper_n, batch_size, lr, pattern):
    ''' Parse and process one .out file. '''
    cout_path = os.path.join(results_dir, 'results', 'hyper%s' % hyper_n,
                             'hyper%s.out' % hyper_n)
    with open(cout_path) as f:
        lines = f.read().splitlines()

    epoch = 0
    list_of_dicts = []

    for line in lines:
        match = pattern.match(line)
        if match is None:
            continue
        logging.debug('Found line: %s', line)
        value = float(match.group(1))
        list_of_dicts.append({
            'epoch': epoch,
            'value': value,
            'hyper_n': hyper_n,
            'batch_size': batch_size,
            'lr': lr,
        })
        # Every match is one epoch.
        epoch += 1

    logging.debug('Found %d epochs in cout_path: %s', epoch, cout_path)
    return list_of_dicts


def build_df(args):
    ''' Parse all .out files and build a pd.DataFrame. '''
    IoU = args.IoU.replace('.', '\\.')
    pattern_str = r' Average Precision.*IoU=%s.*area= *%s.* = ([\\.0-9]+)' % (
        IoU, args.area)
    logging.info("Will look for pattern: '%s'", pattern_str)
    pattern = re.compile(pattern_str)

    results_dir = os.path.join(args.results_root_dir,
                               'campaign%d' % args.campaign,
                               'set%d' % args.set, 'run%d' % args.run)

    if not os.path.exists(args.experiments_path):
        raise FileNotFoundError('Experiment file not found at: %s' %
                                args.experiments_path)

    with open(args.experiments_path) as f:
        lines = f.read().splitlines()

    list_of_dicts = []

    for line in lines:
        logging.debug(line)
        if len(line) == 0:
            continue
        words = line.split(';')

        hyper_n = words[0]
        split = words[1]
        batch_size = int(words[2])
        lr = float(words[3])
        epochs = int(words[4])

        logging.info(
            'Processing experiment %s, split: %s, batch_size: %d, '
            'learning_rate: %f, epochs: %d', hyper_n, split, batch_size, lr,
            epochs)

        if split in args.ignore_splits:
            logging.info('Skipping this split since it is in the ignore list.')
            continue

        list_of_dicts += postprocess_one_run(results_dir, hyper_n, batch_size,
                                             lr, pattern)

    return pd.DataFrame(list_of_dicts)


def main():
    args = get_parser().parse_args()
    logging.basicConfig(
        format='%(levelname)-8s [%(filename)s:%(lineno)d] %(message)s',
        level=args.logging_level)

    df = build_df(args)
    logging.debug('\n%s', str(df))
    if len(df) == 0:
        raise ValueError('Dataframe is empty.')

    df_by_hyper = df.groupby(['hyper_n']).agg({'epoch': ['max']})
    print(df_by_hyper)

    # Get the averages across splits.
    df = df.groupby(['batch_size', 'lr', 'epoch']).agg({
        'value': ['mean']
    }).reset_index()
    df.columns = df.columns.get_level_values(0)
    print(df)

    # Get the best epoch.
    df = df.loc[df.groupby(['batch_size', 'lr'])['value'].idxmax()]
    print(df)


if __name__ == '__main__':
    main()
