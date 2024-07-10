#!/usr/bin/env bash
#
# ----------------------------------------------------------
#
# Copyright 2024 Magenta Stripe Media.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS
# IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# ----------------------------------------------------------
#
# zineset
# Charlotte Koch <charlotte@magentastripe.com>
#
# This script uses GraphicsMagick and Ghostscript to arrange 8 pictures onto
# a single-page PDF document. The page is intended to be printed and then
# folded into a little zine.
#
# The PDF will have placed the individual pages according to the following
# diagram. The arrows point in the direction that will be "up" in the final
# product:
#
# -> [ 8 | 7 ] <-
# -> [ 1 | 6 ] <-
# -> [ 2 | 5 ] <-
# -> [ 3 | 4 ] <-
#

set -e

die() {
  echo "FATAL: $1" 1>&2
  exit 1
}

SPEC=list.txt
GM=gm
PS2PDF=ps2pdf
LOOK_OPT=LOOK_NONE
NO_PDF=no

# 4.25" x 2.75" @ 300 dpi
TILE_SIZE="1275x825"

# 8.5" x 11" @ 300 dpi
TOTAL_SIZE="2550x3300"

# Parse command-line options.
while [ $# -gt 0 ]; do
  case "$1" in
  --help)
    echo "Available looks:"
    echo " - LOOK_NONE"
    echo " - LOOK_XEROX"
    echo " - LOOK_NORMALIZE"
    exit 0
    ;;
  --look)
    LOOK_OPT="$2"; shift 2;
    ;;
  --gm)
    GM="$2"; shift 2;
    ;;
  --spec)
    SPEC="$2"; shift 2;
    ;;
  --no-pdf)
    NO_PDF=yes; shift 1;
    ;;
  *)
    die "unknown option: $1"
    ;;
  esac
done

test -f ${SPEC} || die "couldn't find ${SPEC}"

for image in $(cat ${SPEC}); do
  test -f ${image} || die "couldn't find image: ${image}"
done

temp1="$(mktemp)"
temp2="$(mktemp)"
temp3="$(mktemp)"
temp4="$(mktemp)"
temp5="$(mktemp)"
temp6="$(mktemp)"
temp7="$(mktemp)"
temp8="$(mktemp)"

cleanup() {
  rm -f \
    ${temp1} ${temp2} ${temp3} ${temp4} \
    ${temp5} ${temp6} ${temp7} ${temp8}
}

trap cleanup EXIT

x=0

# Massage each page into a separate file.
for image in $(cat ${SPEC}); do
  x=$((${x}+1))
  if test ${x} -gt 8; then break; fi

  outfile_var=temp${x}
  outfile=${!outfile_var}

  case ${x} in
  1|2|3|8)
    rot_opts="-rotate +90"
    ;;
  *)
    rot_opts="-rotate -90"
    ;;
  esac

  LOOK_XEROX="+dither -colors 4 -monochrome"
  LOOK_NORMALIZE="-normalize"
  LOOK_NONE=""

  look=${!LOOK_OPT}

  set -x

  ${GM} convert ${image} \
    -resize ${TILE_SIZE} \
    ${rot_opts} \
    ${look} \
    miff:${outfile}

  set +x
done

ps_out=zine.ps
real_out=zine.pdf

# Now combine all of the 'massaged' individual pages. Order is important!!
set -x

${GM} montage \
  -geometry ${TILE_SIZE} \
  -tile 2x4 \
  -resize ${TOTAL_SIZE} \
  -page Letter -density 300 \
  ${temp8} \
  ${temp7} \
  ${temp1} \
  ${temp6} \
  ${temp2} \
  ${temp5} \
  ${temp3} \
  ${temp4} \
  ${ps_out}

set +x

if [ "${NO_PDF}" != "yes" ]; then
  set -x
  ${PS2PDF} ${ps_out} ${real_out}
  set +x
fi
