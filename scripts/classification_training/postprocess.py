'''
This file reads and analyzes .out files created by classification training scripts.
The result of the analysis is how different hyperparameters perform.
The best model can be copied to the default "best" filepath.
The output of this script goes to google sheets.
'''

import os, sys
import re
import logging
import argparse
import shutil
import pandas as pd
import glob


def get_pattern():
    pattern_str = r'Eval-Accuracy top1 : ([\\.0-9]+)%'
    logging.info("Will look for pattern: '%s'", pattern_str)
    pattern = re.compile(pattern_str)
    return pattern


def get_parser():
    parser = argparse.ArgumentParser(
        description="Postprocess results of training.")

    parser.add_argument(
        "--experiments_path",
        required=True,
        help=
        'Call $(get_classification_experiments_path ${campaign_id} ${set_id} ${run_id}) '
        'and provide the result')
    parser.add_argument(
        "--classification_dir",
        required=True,
        help='Provide ${CLASSIFICATION_DIR} from "constants.sh".')
    parser.add_argument("--campaign_id", type=int, required=True)
    parser.add_argument("--set_id", required=True)
    parser.add_argument("--run_id", required=True)
    parser.add_argument("--ignore_splits",
                        nargs='*',
                        default=['full'],
                        help='The splits with this name are not imported.')
    parser.add_argument(
        "--copy_best_model_from_split",
        help=
        'Copy the best model from this split to folder ${run_id}/besthyper. '
        'If specified, it should normally be "full".')
    # parser.add_argument(
    #     "--clean_up",
    #     type=bool,
    #     default=False,
    #     help='If true, will delete all snapshots except the best one. '
    #     'If copy_best_model_from_split is None, has no effect.')
    parser.add_argument(
        "--logging_level",
        type=int,
        choices=[10, 20, 30, 40],
        default=20,
        help="Set logging level. 10: debug, 20: info, 30: warning, 40: error.")
    return parser


def process_one_run(run_dir, hyper_n, config_prefix):
    ''' Parse and process one .out file. '''
    cout_path = os.path.join(run_dir, 'hyper%s' % hyper_n,
                             'batch_job/train_classification.out')
    logging.info('Reading cout file "%s"', cout_path)
    with open(cout_path) as f:
        lines = f.read().splitlines()

    epoch = 0
    list_of_dicts = []

    pattern = get_pattern()

    # The output from stage1 and stage2 are written to the same output file.
    has_started_stage_2 = False

    for line in lines:
        if line.startswith('Loading stamps Stage 1 Classifier Weights'):
            has_started_stage_2 = True
            continue
        elif not has_started_stage_2:
            continue

        match = pattern.match(line)
        if match is None:
            continue
        logging.debug('Found line: %s', line)
        value = float(match.group(1))
        list_of_dicts.append({
            'epoch': epoch,
            'value': value,
            'hyper_n': hyper_n,
            'config_prefix': config_prefix,
        })
        # Every match is one epoch.
        epoch += 1

    logging.debug('Found %d epochs in cout_path: %s', epoch, cout_path)
    return list_of_dicts


def build_df(args, run_dir):
    ''' Parse all .out files and build a pd.DataFrame. '''

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
        config_prefix = words[2]

        logging.info('Processing experiment %s, split: %s, config_prefix: %s.',
                     hyper_n, split, config_prefix)

        if split == args.copy_best_model_from_split:
            logging.info('Will get this experiment.')
            hyper_to_hyper_n_map_for_copy[config_prefix] = hyper_n

        elif split in args.ignore_splits:
            logging.info('Skipping this split since it is in the ignore list.')

        else:
            list_of_dicts_to_eval += process_one_run(run_dir, hyper_n,
                                                     config_prefix)

    return pd.DataFrame(list_of_dicts_to_eval), hyper_to_hyper_n_map_for_copy


def main():
    args = get_parser().parse_args()
    logging.basicConfig(
        format='%(levelname)-8s [%(filename)s:%(lineno)d] %(message)s',
        level=args.logging_level)

    run_dir = os.path.join(args.classification_dir,
                           'campaign%d' % args.campaign_id, args.set_id,
                           'run%s' % args.run_id)

    df, hyper_to_hyper_n_map_for_copy = build_df(args, run_dir)
    logging.debug('\n%s', str(df))
    if len(df) == 0:
        raise ValueError('Dataframe is empty.')

    df_by_hyper = df.groupby(['hyper_n']).agg({'epoch': ['max']})
    logging.info(df_by_hyper)

    # Get the averages across splits.
    df = df.groupby(['config_prefix', 'epoch']).agg({
        'value': ['mean']
    }).reset_index()
    df.columns = df.columns.get_level_values(0)
    logging.info(df)

    # Get the best epoch.
    df = df.loc[df.groupby(['config_prefix'])['value'].idxmax()]
    logging.info('The best epoch from every hyperparameter')
    logging.info(df)

    # Get the best hyperparameters.
    df = df.loc[df['value'].idxmax()]
    logging.info('The best hyperparameter and epoch')
    logging.info(df)

    print(df['config_prefix'], df['epoch'])

    df.to_csv(os.path.join(run_dir, 'results.csv'))

    # Id of the best hyperparameter in 'full' split.
    if args.copy_best_model_from_split is not None:
        if (df['config_prefix']) not in hyper_to_hyper_n_map_for_copy:
            logging.error(
                'Cant copy the best model - the best hyperparameters '
                'are not in split %s', args.copy_best_model_from_split)
            sys.exit(1)

        hyper_n = int(hyper_to_hyper_n_map_for_copy[(df['config_prefix'])])

        epoch_in_filename = df['epoch'] + 1
        hyper_dir = os.path.join(run_dir, 'hyper%03d' % hyper_n)
        snapshot_path = os.path.join(hyper_dir, 'stage2',
                                     'epoch%03d.pth' % epoch_in_filename)
        if not os.path.exists(snapshot_path):
            logging.error(
                'A snaphot file for split "%s" and the best hyperparameters '
                'does not exist at:\n\t%s', args.copy_best_model_from_split,
                snapshot_path)
            sys.exit(1)

        best_hyper_dir = os.path.join(run_dir, 'hyperbest')
        if os.path.exists(best_hyper_dir):
            logging.warning('Best hyper dir already exists. Deleting it.')
            shutil.rmtree(best_hyper_dir)

        # Copy best snapshot.
        best_snapshot_dir = os.path.join(best_hyper_dir, 'stage2')
        out_best_snapshot_path = os.path.join(best_snapshot_dir,
                                              'final_model_checkpoint.pth')
        if not os.path.exists(best_snapshot_dir):
            os.makedirs(best_snapshot_dir)
        shutil.copyfile(snapshot_path, out_best_snapshot_path)

        logging.info('Copied the best model from:\n\t%s\nto\n\t%s',
                     snapshot_path, out_best_snapshot_path)

        # Copy every extra file in hyper_dir to "hyperbest" dir.
        files_names = [
            f for f in os.listdir(hyper_dir)
            if os.path.isfile(os.path.join(hyper_dir, f))
        ]
        for file_name in files_names:
            old_file_path = os.path.join(hyper_dir, file_name)
            new_file_path = os.path.join(best_hyper_dir, file_name)
            logging.info('Copying from:\n\t%s\nto\n\t%s', old_file_path,
                         new_file_path)
            shutil.copyfile(old_file_path, new_file_path)

        # logging.warning('Clean up is set to %s. Will ignore it.',
        #                 'TRUE' if args.clean_up else 'FALSE')
        # if args.clean_up:
        #     count = 0
        #     for hyper_dir in glob.glob(
        #             os.path.join(args.classification_dir,
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
