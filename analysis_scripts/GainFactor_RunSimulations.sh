#!/bin/bash
## Runs simulations cycling through numbers of GPU blocks.

DIRECTORY="GainFactor_Tesla"
NOFSIMSPERTHREAD=1000
MARRAY=(1 10 100 200 300 400)

echo "This will overwrite all existing output. Are you sure you want to run this? y/[n]"
read response

case "$response" in
	[yY][eE][sS]|[yY])
		:
		;;
	*)
		echo "Aborting..."
		exit 3
		;;
esac

cd ..;
rm -rf outputs/${DIRECTORY}/output*;
rm -rf inputs/${DIRECTORY}/input*;
for m in ${MARRAY[@]}; do
	for i in {1..88..10}; do
		echo "${i}, ${m}";
		sed -e "s/_gpu_blocks_/$i/g" \
			-e "s/_underlying_initial_price_/100/g" \
			-e "s/_volatility_/0.25/g" \
			-e "s/_riskfreerate_/0.0001/g" \
			-e "s/_ttm_/1/g" \
			-e "s/_intervals_/$m/g" \
			-e "s/_option_type_/e/g" \
			-e "s/_strike_price_/100/g" \
			-e "s/_B_/1/g" \
			-e "s/_K_/0.3/g" \
			-e "s/_N_/1/g" \
			-e "s/_simulations_/$((NOFSIMSPERTHREAD * 512 * i))/g" \
			-e "s/_cpugpu_/b/g" \
			-e "s/_gauss_bimodal_/g/g" \
			input.dat.template | tee input.dat "inputs/${DIRECTORY}/input__${i}_${m}.dat" > /dev/null;
		./main.x > "outputs/${DIRECTORY}/output__${i}_${m}.dat";
	done
done

exit 0
