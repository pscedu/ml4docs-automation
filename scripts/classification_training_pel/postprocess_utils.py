''' Code common for all postprocess scripts should be moved here. '''

import os
import glob
import logging


def find_output_file(run_dir, hyper_n):
    cout_pattern = os.path.join(run_dir, 'hyper%s' % hyper_n,
                                'batch_jobs/train_classification*.out')
    cout_paths = glob.glob(cout_pattern)
    if len(cout_paths) == 0:
        raise FileNotFoundError(
            'Output file is not found with pattern:\n\t%d' % cout_pattern)
    elif len(cout_paths) > 1:
        raise Exception(
            'Several files match pattern.\n\t- %s'
            '\nEach run_id is supposed to be run only once. '
            'If you ran this run_id several times, delete all but needed file.'
            % '\n\t- '.join(cout_paths))
    cout_path = cout_paths[0]
    logging.info('Reading cout file "%s"', cout_path)
    return cout_path
