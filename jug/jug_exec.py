#!/usr/bin/env python
from jug import is_jug_running

if is_jug_running():
    from sys import argv
    from jug.utils import jug_execute
    jug_execute(argv[1:])
else:
    from sys import argv
    from jug.jug import main
    main(["jug", "execute", __file__] + argv[1:])
