#!/usr/bin/env bash
# Makes a product photo 4:3 (1400x1050) without cutting the animal off.
#
#   ./scripts/reframe-photo.sh <in.jpg> <out.jpg> <x0> <x1>
#
# x0 and x1 are fractions of the source width that must stay in frame (where the
# fish starts and ends, plus a margin; measure them by eye on the source). The
# crop is widened to 4:3 where the source allows. Where it does not -- the fish
# is wider than a 4:3 window of the source -- the canvas is extended above and
# below (or beside) with a blurred copy of the photo itself, feathered at the
# seam. Those bands are synthetic, so say so in species/CREDITS.md.
#
# Why this exists: object-fit:cover in a 4:3 box centre-crops anything that is
# not 4:3, and a centre crop cut 6-35% off ten photos, tails and snouts
# included (crop audit, 30 September 2026). Needs ImageMagick 6 and python3.
set -euo pipefail
S=$(mktemp -d); trap 'rm -rf "$S"' EXIT
in=$1 out=$2 a=$3 b=$4
read W H < <(identify -format "%w %h\n" "$in")
x0=$(python3 -c "print(int($a*$W))"); x1=$(python3 -c "print(int($b*$W))"); cw=$((x1-x0))
want=$(python3 -c "print(round($H*4/3))")
if [ $cw -lt $want ]; then
  # widen around the centre, clamped to the source
  x0=$(python3 -c "c=($x0+$x1)/2; x=int(c-$want/2); print(max(0,min(x,$W-$want)))"); cw=$want
  [ $cw -gt $W ] && cw=$W
fi
TW=$cw; TH=$(python3 -c "print(max($H, round($cw*3/4)))")
if [ $(python3 -c "print(int($TW/$TH*1000))") -lt 1333 ]; then TW=$(python3 -c "print(round($TH*4/3))"); fi
F=$(( (TH-H)/2 > (TW-cw)/2 ? (TH-H)/2 : (TW-cw)/2 )); F=$(( F>0 ? (F<60?F:60) : 0 ))
# Feather only the edges that meet synthetic canvas, so the seam fades instead of reading as a letterbox.
convert "$in" -crop ${cw}x${H}+${x0}+0 +repage $S/crop.png
if [ $F -gt 0 ]; then
  if [ $TH -gt $H ]; then
    convert -size ${cw}x${F} gradient:black-white $S/g1.png; convert $S/g1.png -flip $S/g2.png
    convert -size ${cw}x${H} xc:white $S/g1.png -gravity north -composite $S/g2.png -gravity south -composite $S/mask.png
  else
    convert -size ${H}x${F} gradient:black-white -rotate 90 $S/g1.png; convert $S/g1.png -flop $S/g2.png
    convert -size ${cw}x${H} xc:white $S/g2.png -gravity west -composite $S/g1.png -gravity east -composite $S/mask.png
  fi
  convert $S/crop.png $S/mask.png -alpha off -compose CopyOpacity -composite $S/fg.png
else cp $S/crop.png $S/fg.png; fi
convert $S/fg.png \
  \( +clone -alpha off -resize ${TW}x${TH}^ -gravity center -extent ${TW}x${TH} -virtual-pixel edge -blur 0x35 -modulate 90 \) +swap \
  -gravity center -compose over -composite -resize 1400x1050 -extent 1400x1050 -quality 80 -strip "$out"
echo "$(basename $out): src ${W}x${H}, keep x ${x0}+${cw}, canvas ${TW}x${TH}, pad $(( (TH-H)/2 ))px top/bottom $(( (TW-cw)/2 ))px sides"
