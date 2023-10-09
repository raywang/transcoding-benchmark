#
# Script to do benchmark test for CPU transcoding performance with h.265 codec settings,
# log the performance result (frames per second) and upload the transcoded files to given s3 bucket
#
# Usage:    bash 265to265_benchmark_cpu.sh <batch size> <transcoding bitrate> <s3 bucket name> <filename>
#
#           batch size:             concurrent number of ffmpeg transcoding process (make cpu utilization close to 100%)
#           transcoding bitrate:    bitrate for transcoding, e.g. 800k, 2M
#           s3 bucket name:         name of the bucket, which should include 'input' and 'output' folders
#           file name:              name of the sample file
#
# Sample:   bash 265to265_benchmark_cpu.sh 5 8M ffmpeg-on-graviton-ap-northeast-1 MERIDIAN_3840x2160p60_HEVC_18Mbps_AAC_Stereo.mp4
#
# Please make sure INPUT_BUCKET, OUTPUT_BUCKET and INPUT_FILE are set properly
#

sudo dnf -y install dmidecode tmux

BATCH_SIZE=$1
INSTANCE=$(sudo dmidecode -s system-product-name)
BITRATE=$2
INPUT_BUCKET=s3://$3/input/
OUTPUT_BUCKET=s3://$3/output/
INPUT_FILE=$4
INPUT_FOLDER=`pwd`/input
OUTPUT_FOLDER=`pwd`/output/${INSTANCE}
LOGS_FOLDER=`pwd`/logs/${INSTANCE}
LOG_FILE=${LOGS_FOLDER}/results.log
TEMP_FOLDER=`pwd`/temp

PROFILE="main"
CODEC="libx265"

VCPU=`nproc`

if [ -z $1 ]; then
    BATCH_SIZE=5
fi


if [ -z $2 ]; then
    BITRATE=8M
fi

#ffmpeg -y -hwaccel auto -i $i -c:v libx265 -pix_fmt yuv420p -profile:v main -preset faster -x265-params bframes=2:rc-lookahead=3 -b:v 4M -c:a copy out.mp4

batch_transcoding_process() {

    name=${INPUT_FILE%.*}
    output="${name}-${CODEC}-${INSTANCE}-${BITRATE}"
    temp_log=${LOGS_FOLDER}/temp/${output}

    for ((n=0;n<$BATCH_SIZE;n++)); do
        echo "batch job id $n start..."
        if [ $n -eq $((BATCH_SIZE-1)) ]; then
            echo "please waiting for the transcoding jobs complete..."
            ffmpeg -y -hwaccel auto -i ${INPUT_FOLDER}/${INPUT_FILE} -c:v ${CODEC} -vtag hvc1 -pix_fmt yuv420p -profile:v ${PROFILE} -preset faster -x265-params bframes=2:rc-lookahead=3 -b:v ${BITRATE} -c:a copy ${TEMP_FOLDER}/${output}_$n.mp4 2>&1 | tee ${temp_log}_$n.log
        else
            tmux new -d "ffmpeg -y -hwaccel auto -i ${INPUT_FOLDER}/${INPUT_FILE} -c:v ${CODEC} -vtag hvc1 -pix_fmt yuv420p -profile:v ${PROFILE} -preset faster -x265-params bframes=2:rc-lookahead=3 -b:v ${BITRATE} -c:a copy ${TEMP_FOLDER}/${output}_$n.mp4 2>&1 | tee ${temp_log}_$n.log"
        fi
    done

    echo "transcoding jobs complete..."
    sleep 3
    #wait_for_cpu_idle

    fps_total=0
    cpu_usage_total=0

    for ((n=0;n<$BATCH_SIZE;n++)); do

        # Get CPU usage
        #user=`cat ${temp_log}_$n.log | awk '/user/ {print $2}' | awk -F'm' '{printf 60*int($1*100)/100+int($2*100)/100}'`
        #real=`cat ${temp_log}_$n.log | awk '/real/ {print $2}' | awk -F'm' '{printf 60*int($1*100)/100+int($2*100)/100}'`
        #cpu_usage=`echo "scale=4;$user/$real/$VCPU*100;" | bc`
        #cpu_usage_total=`echo "$cpu_usage_total+$cpu_usage" | bc`

        # Get ffmpeg transcoding frames per second 
        fps=`cat ${temp_log}_$n.log | awk -F'=' '/fps=/ {print $(NF-7)}' | awk '{print $1}'`
        fps_total=`echo "$fps_total+$fps" | bc`

        # Log cpu_usage and fps
        #echo "${output} trancode job #$n cpu_usage:$cpu_usage fps:${fps} frames per second"
        #echo "${output} trancode job #$n cpu_usage:$cpu_usage fps:${fps} frames per second" >> ${LOG_FILE}
        echo "${output} trancode job #$n fps:${fps} frames per second"
        echo "${output} trancode job #$n fps:${fps} frames per second" >> ${LOG_FILE}

    done

    #echo "${output} trancode jobs total cpu_usage:$cpu_usage_total fps:${fps_total} frames per second"
    #echo "${output} trancode jobs total cpu_usage:$cpu_usage_total fps:${fps_total} frames per second" >> ${LOG_FILE}
    echo "${output} trancode jobs total fps:${fps_total} frames per second"
    echo "${output} trancode jobs total fps:${fps_total} frames per second" >> ${LOG_FILE}

}

wait_for_cpu_idle() {
    current=$(mpstat | awk '$13 ~ /[0-9.]+/ { print 100 - $13 }')
    echo "cpu usage: $current%"
    while [ $(echo "$current>25" | bc) -eq 1 ]; do
        current=$(mpstat | awk '$13 ~ /[0-9.]+/ { print 100 - $13 }')
        echo "cpu usage: $current%, the latest transcoding job may not finished yet"
        sleep 5
    done
}

## step 1 - download input files

mkdir -p ${INPUT_FOLDER} ${OUTPUT_FOLDER} ${LOGS_FOLDER} ${TEMP_FOLDER} ${LOGS_FOLDER}/temp

FILE=${INPUT_FOLDER}/${INPUT_FILE}
if [ -f "$FILE" ]; then
    echo "$INPUT_FILE exists, no need to download again."
else
    echo "$INPUT_FILE doesn't exist, start to download from S3."
    aws s3 sync ${INPUT_BUCKET} ${INPUT_FOLDER}
fi

## step 2 - transcoding input files

echo "======================================================" >> ${LOG_FILE}
batch_transcoding_process 

## step 3 upload results
#cp ${TEMP_FOLDER}/${output}_0.mp4 ${OUTPUT_FOLDER}/"${INPUT_FILE%.*}_${CODEC}_${BITRATE}.mp4"
#aws s3 sync ${OUTPUT_FOLDER} ${OUTPUT_BUCKET}${INSTANCE}

## step 4 clean jobs
#rm -rf ${TEMP_FOLDER}
