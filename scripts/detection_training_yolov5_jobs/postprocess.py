'''
This file reads and analyzes .out files created by detection training scripts.
The result of the analysis is how different hyperparameters perform.
The output of this script goes to google sheets.
'''

import os, sys, os.path as op
import re
import logging
import argparse
import shutil
import pandas as pd


def get_parser():
    parser = argparse.ArgumentParser(
        description="Postprocess results of training.")

    parser.add_argument("--experiments_path", required=True)
    parser.add_argument("--campaign_id", type=int, required=True)
    parser.add_argument("--set_id", type=str, required=True)
    parser.add_argument("--run_id", type=str, required=True)
    parser.add_argument("--ignore_splits",
                        nargs='*',
                        default=['full'],
                        help='The splits with this name are not imported.')
    parser.add_argument("--copy_best_model_from_split",
                        default='full',
                        help='Will copy the best model from this split.')
    parser.add_argument("--detection_root_dir", required=True)
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


def postprocess_one_run(run_dir, hyper_n, batch_size, lr):
    ''' Parse and process one .out file. '''
    results_path = os.path.join(run_dir, 'hyper%s' % hyper_n, 'exp',
                                'results.csv')
    if not op.exists(results_path):
        raise FileNotFoundError('File does not exist: %s.', results_path)

    df = pd.read_csv(results_path,
                     sep=',\ *',
                     usecols=[
                         'epoch', 'metrics/precision', 'metrics/recall',
                         'metrics/mAP_0.5'
                     ])
    df['hyper_n'] = hyper_n
    df['batch_size'] = batch_size
    df['lr'] = lr

    logging.debug('Found %d epochs in results_path: %s', len(df), results_path)
    return df


def build_df(args):
    ''' Parse all .out files and build a pd.DataFrame. '''

    if not op.exists(args.experiments_path):
        raise FileNotFoundError('Experiment file not found at: %s' %
                                args.experiments_path)

    run_dir = op.dirname(args.experiments_path)
    if not op.exists(run_dir):
        raise FileNotFoundError('Run dir not found at: %s' % run_dir)

    with open(args.experiments_path) as f:
        lines = f.read().splitlines()

    df = None  # Lazy init.
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
            df_hyper = postprocess_one_run(run_dir, hyper_n, batch_size, lr)
            if df is None:  # Lazy init.
                df = df_hyper
            else:
                df = pd.concat([df, df_hyper])

    return df, hyper_to_hyper_n_map_for_copy


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
        'metrics/mAP_0.5': ['mean']
    }).reset_index()
    df.columns = df.columns.get_level_values(0)
    logging.info(df)

    # Get the best epoch.
    df = df.loc[df.groupby(['batch_size', 'lr'])['metrics/mAP_0.5'].idxmax()]
    logging.info('The best epoch from every hyperparameter')
    logging.info(df)

    # Get the best hyperparameters.
    df = df.loc[df['metrics/mAP_0.5'].idxmax()]
    logging.info('The best hyperparameter and epoch')
    logging.info(df)

    run_dir = op.join(args.detection_root_dir, 'campaign%d' % args.campaign_id,
                      args.set_id, 'run%s' % args.run_id)
    df.to_csv(op.join(run_dir, 'results.csv'))

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
        snapshot_path = op.join(args.detection_root_dir,
                                'campaign%d' % args.campaign_id, args.set_id,
                                'run%s' % args.run_id, 'hyper%03d' % hyper_n,
                                'exp/weights/last.pt')
        # TODO: should use epoch, but YOLOv5 saves only best and last: 'epoch%02d.h5' % df['epoch'])
        if not op.exists(snapshot_path):
            logging.error(
                'A snaphot file for split "%s" and the best hyperparameters '
                'does not exist at:\n\t%s', args.copy_best_model_from_split,
                snapshot_path)
            sys.exit(1)

        # Copy.
        best_snapshot_name = 'hyper%03d_epoch_last.pt' % hyper_n
        best_snapshot_path = op.join(run_dir, best_snapshot_name)
        shutil.copyfile(snapshot_path, best_snapshot_path)
        if not op.exists(best_snapshot_path):
            logging.error('Failed to copy best snapshot from:\n\t%s\nto\n\t%s',
                          snapshot_path, best_snapshot_path)
            sys.exit(1)

        # Symlink.
        best_snapshot_dir = op.join(args.detection_root_dir,
                                    'campaign%d' % args.campaign_id,
                                    args.set_id)
        symlink_path = op.join(
            best_snapshot_dir,
            'snapshots_best_%s.pt' % args.copy_best_model_from_split)
        if op.exists(symlink_path):
            os.remove(symlink_path)
            logging.debug('Symlink already existed, deleted it:\n\t%s',
                          symlink_path)
        os.symlink(op.join('run%s' % args.run_id, best_snapshot_name),
                   symlink_path)
        if not op.exists(symlink_path):
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
        #             op.join(args.results_root_dir,
        #                          'campaign%d' % args.campaign_id,
        #                          'set%s' % args.set_id, 'run%s' % args.run_id,
        #                          'results', 'hyper???')):
        #         for snaphot_path in glob.glob(
        #                 op.join(hyper_dir, 'snapshots/*.h5')):
        #             logging.debug('Deleting %s', snaphot_path)
        #             os.remove(snaphot_path)
        #             count += 1
        #     logging.info('Removed %d snapshots.', count)


if __name__ == '__main__':
    main()
