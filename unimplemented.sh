#!/bin/sh

echo >&2 "fatal: shit was built without support for $(basename $0) (@@REASON@@)."
exit 128
