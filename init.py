#!/usr/bin/env python

import re
from subprocess import check_output
ips = check_output(['hostname', '--all-ip-address'])
prefix = re.match(r"^(\d+)\..*", ips).group(1)
prefix = "{}.*".format(prefix)

from yaml import load, dump, FullLoader as Loader, Dumper

file = '/root/root/conf.yaml'
instream = open(file, 'r')
conf = load(instream, Loader=Loader)
instream.close()
conf['ips']['allow'] = [prefix]
outstream = open(file, 'w')
outstream.write(dump(conf, Dumper=Dumper))
outstream.close()
