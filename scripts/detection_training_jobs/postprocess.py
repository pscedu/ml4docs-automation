'''
This file reads and analyzes .out files created by detection training scripts.
The result of the analysis is how different hyperparameters perform.
The output of this script goes to google sheets.
'''

import os, sys
import re
import logging
import argparse
import shutil
import pandas as pd
import glob


def get_parser():
    parser = argparse.ArgumentParser(
        description="Postprocess results of training.")

    parser.add_argument("--experiments_path", required=True)
    parser.add_argument("--campaign", type=int, required=True)
    parser.add_argument("--set", type=str, required=True)
    parser.add_argument("--run", type=str, required=True)
    parser.add_argument("--ignore_splits",
                        nargs='*',
                        default=['full'],
                        help='The splits with this name are not imported.')
    parser.add_argument("--copy_best_model_from_split",
                        default='full',
                        help='Will copy the best model from this split.')
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
        "--clean_up",
        type=bool,
        default=False,
        help='If true, will delete all snapshots except the best one. '
        'If copy_best_model_from_split is None, has no effect.')
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
                               'set%s' % args.set, 'run%s' % args.run)

    if not os.path.exists(args.experiments_path):
        raise FileNotFoundError('Experiment file not found at: %s' %
                                args.experiments_path)

    with open(args.experiments_path) as f:
        lines = f.read().splitlines()

    list_of_dicts_to_eval = []
    hyper_to_hyper_n_map_for_copy = {}

    for line in lines:
        logging.debug(line)
        if len(line) == 0 or line.startswith('#'):
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

        if split == args.copy_best_model_from_split:
            logging.info('Will get this experiment.')
            hyper_to_hyper_n_map_for_copy[(batch_size, lr)] = hyper_n

        elif split in args.ignore_splits:
            logging.info('Skipping this split since it is in the ignore list.')

        else:
            list_of_dicts_to_eval += postprocess_one_run(
                results_dir, hyper_n, batch_size, lr, pattern)

    return pd.DataFrame(list_of_dicts_to_eval), hyper_to_hyper_n_map_for_copy


def main():
    args = get_parser().parse_args()
    logging.basicConfig(
        format='%(levelname)-8s [%(filename)s:%(lineno)d] %(message)s',
        level=args.logging_level)

    df, hyper_to_hyper_n_map_for_copy = build_df(args)
    logging.debug('\n%s', str(df))
    if len(df) == 0:
        raise ValueError('Dataframe is empty.')

    df_by_hyper = df.groupby(['hyper_n']).agg({'epoch': ['max']})
    logging.info(df_by_hyper)

    # Get the averages across splits.
    df = df.groupby(['batch_size', 'lr', 'epoch']).agg({
        'value': ['mean']
    }).reset_index()
    df.columns = df.columns.get_level_values(0)
    logging.info(df)

    # Get the best epoch.
    df = df.loc[df.groupby(['batch_size', 'lr'])['value'].idxmax()]
    logging.info('The best epoch from every hyperparameter')
    logging.info(df)

    # Get the best hyperparameters.
    df = df.loc[df['value'].idxmax()]
    logging.info('The best hyperparameter and epoch')
    logging.info(df)

    print(df['batch_size'], df['lr'], df['epoch'])

    # Id of the best hyperparameter in 'full' split.
    if args.copy_best_model_from_split is not None:
        if (df['batch_size'], df['lr']) not in hyper_to_hyper_n_map_for_copy:
            logging.error(
                'Cant copy the best model - the best hyperparameters '
                'are not in split %s', args.copy_best_model_from_split)
            sys.exit(1)

        hyper_n = int(hyper_to_hyper_n_map_for_copy[(df['batch_size'],
                                                     df['lr'])])
        snapshot_path = os.path.join(args.results_root_dir,
                                     'campaign%d' % args.campaign,
                                     'set%s' % args.set, 'run%s' % args.run,
                                     'results', 'hyper%03d' % hyper_n,
                                     'snapshots',
                                     'resnet50_coco_%02d.h5' % df['epoch'])
        if not os.path.exists(snapshot_path):
            logging.error(
                'A snaphot file for split "%s" and the best hyperparameters '
                'does not exist at:\n\t%s', args.copy_best_model_from_split,
                snapshot_path)
            sys.exit(1)

        # Copy.
        best_snapshot_dir = os.path.join(args.results_root_dir,
                                         'campaign%d' % args.campaign,
                                         'set%s' % args.set)
        best_snapshot_name = 'run%s_hyper%03d_resnet50_coco_%02d.h5' % (
            args.run, hyper_n, df['epoch'])
        best_snapshot_path = os.path.join(best_snapshot_dir,
                                          best_snapshot_name)
        shutil.copyfile(snapshot_path, best_snapshot_path)
        if not os.path.exists(best_snapshot_path):
            logging.error('Failed to copy best snapshot from:\n\t%s\nto\n\t%s',
                          snapshot_path, best_snapshot_path)
            sys.exit(1)

        # Symlink.
        symlink_path = os.path.join(
            best_snapshot_dir,
            'snapshots_best_%s.h5' % args.copy_best_model_from_split)
        if os.path.exists(symlink_path):
            os.remove(symlink_path)
            logging.debug('Symlink already existed, deleted it:\n\t%s',
                          symlink_path)
        os.symlink(best_snapshot_name, symlink_path)
        if not os.path.exists(symlink_path):
            logging.error('Failed to write symlink to:\n\t%s', symlink_path)
            sys.exit(1)

        logging.info(
            'Copied the best model from:\n\t%s\nto\n\t%s\nand symlinked as\n\t%s',
            snapshot_path, best_snapshot_path, symlink_path)

        logging.warning('Clean up is set to %s. Will ignore it.',
                        'TRUE' if args.clean_up else 'FALSE')
        # if args.clean_up:
        #     count = 0
        #     for hyper_dir in glob.glob(
        #             os.path.join(args.results_root_dir,
        #                          'campaign%d' % args.campaign,
        #                          'set%s' % args.set, 'run%s' % args.run,
        #                          'results', 'hyper???')):
        #         for snaphot_path in glob.glob(
        #                 os.path.join(hyper_dir, 'snapshots/*.h5')):
        #             logging.debug('Deleting %s', snaphot_path)
        #             os.remove(snaphot_path)
        #             count += 1
        #     logging.info('Removed %d snapshots.', count)


if __name__ == '__main__':
    main()
