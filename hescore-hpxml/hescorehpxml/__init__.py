import argparse
import logging
import os
import sys
from jsonschema import ValidationError, SchemaError
from .base import HPXMLtoHEScoreTranslatorBase
from .hpxml2 import HPXML2toHEScoreTranslator
from .hpxml3 import HPXML3toHEScoreTranslator
from .exceptions import HPXMLtoHEScoreError


def HPXMLtoHEScoreTranslator(hpxmlfilename):
    schema_version = HPXMLtoHEScoreTranslatorBase.detect_hpxml_version(hpxmlfilename)
    major_version = schema_version[0]
    if major_version == 3:
        return HPXML3toHEScoreTranslator(hpxmlfilename)
    elif major_version == 2:
        return HPXML2toHEScoreTranslator(hpxmlfilename)
    else:
        raise HPXMLtoHEScoreError('Schema version {} not supported.'.format('.'.join(schema_version)))


def main(argv=sys.argv[1:]):
    parser = argparse.ArgumentParser(description='Convert HPXML v2.x or v3.x files to HEScore inputs')
    parser.add_argument(
        'hpxml_input',
        help='Filename of hpxml file'
    )
    parser.add_argument(
        '-o', '--output',
        type=argparse.FileType('w'),
        default=sys.stdout,
        help='Filename of output file in json format. If not provided, will go to stdout.'
    )
    parser.add_argument(
        '--bldgid',
        help='HPXML building id to score if there are more than one <Building/> elements. Default: first one.'
    )
    parser.add_argument(
        '--projectid',
        help='HPXML project id to use in translating HPwES data if there are more than one <Project/> elements. Default: first one.' # noqa 501
    )
    parser.add_argument(
        '--contractorid',
        help='HPXML contractor id to use in translating HPwES data if there are more than one <Contractor/> elements. Default: first one.' # noqa 501
    )
    parser.add_argument(
        '--scrubbed-hpxml',
        type=argparse.FileType('wb'),
        help='Path to save HPXML file scrubbed of PII.'
    )

    args = parser.parse_args(argv)
    logging.basicConfig(level=logging.ERROR, format='%(levelname)s:%(message)s')

    def remove_scrubbed_hpxml_file():
        if args.scrubbed_hpxml:
            args.scrubbed_hpxml.close()
            os.remove(args.scrubbed_hpxml.name)

    try:
        t = HPXMLtoHEScoreTranslator(args.hpxml_input)
    except HPXMLtoHEScoreError as ex:
        exclass = type(ex).__name__
        logging.error('%s:%s', exclass, str(ex))
        remove_scrubbed_hpxml_file()
        sys.exit(1)
    except Exception:
        logging.error('Unknown HPXML Translation Error: Please contact HEScore support')
        remove_scrubbed_hpxml_file()
        sys.exit(2)

    try:
        t.hpxml_to_hescore_json(
            args.output,
            hpxml_bldg_id=args.bldgid,
            hpxml_project_id=args.projectid,
            hpxml_contractor_id=args.contractorid
        )
    except (HPXMLtoHEScoreError, ValidationError, SchemaError) as ex:
        exclass = type(ex).__name__
        logging.error('%s:%s', exclass, str(ex))
        sys.exit(1)
    except Exception:
        logging.error('Unknown HPXML Translation Error: Please contact HEScore support')
        sys.exit(2)
    finally:
        if args.scrubbed_hpxml:
            t.export_scrubbed_hpxml(args.scrubbed_hpxml)


if __name__ == '__main__':
    main()
