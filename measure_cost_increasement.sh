#!/bin/bash

show_msg() {
    echo "\033[36m$1\033[0m"
}

show_result() {
    echo "\033[33m$1\033[0m"
}

show_err() {
    echo "\033[31m$1\033[0m"
}

# Check input
if [ "$#" -ne 4 ]; then
    show_err "Need to input the test video resource directory path, the split size and repeat times!"
    show_err "The input format should be ./split_video.sh directory 2 2 4"
    show_err "to do the measurement on dataset 'directory' with split size 2x2 and repeat every file 4 times"
    exit 1
fi

video_directory=$1
show_msg "The input test directory is '$video_directory'"

if [ ! -d "$video_directory" ]; then
  show_err "The test directory '$video_directory' does not exist!"
  exit 1
fi

width_split_num=$2
height_split_num=$3
repeat_times=$4
show_msg "The split size will be $width_split_num x $height_split_num."

if [ $width_split_num -le 0 ] || [ $height_split_num -le 0 ] || [ $repeat_times -le 0 ]; then
  show_err "The input split size and repeat time should be greater than 0!"
  exit 1
fi

# finish check input

#------------ Split videos -----------------------
./split_video.sh $video_directory $width_split_num $height_split_num
#-------------------------------------------------

cd $video_directory

# Final result file
decode_result_file="decode_result.csv"
encode_result_file="encode_result.csv"
if test -f $decode_result_file; then
    show_msg "The result file:$decode_result_file has already exsisted, delete it"
    rm $decode_result_file
fi
if test -f $encode_result_file; then
    show_msg "The result file:$encode_result_file has already exsisted, delete it"
    rm $encode_result_file
fi

# Create result csv header
split_num=`expr $width_split_num \* $height_split_num`
printf "Filename,Decode Cost," >> $decode_result_file
for (( i = 0; i < $split_num; i++ )); do
    printf "SubVideo$i Decode Cost," >> $decode_result_file
done
printf "SubVideo DecodeSummary,Cost Increasement,Frame Count,Avg Frame increasement\n" >> $decode_result_file

printf "Filename,Encode Cost," >> $encode_result_file
for (( i = 0; i < $split_num; i++ )); do
    printf "SubVideo$i Encode Cost," >> $encode_result_file
done
printf "SubVideo Encode Summary,Cost Increasement,Frame Count,Avg Frame increasement\n" >> $encode_result_file

#------------ Decode and Encode Statistic -------------
yuv_result="temp_result.yuv"
encoded_videos="videos_reencoded"

if [ -d "$encoded_videos" ]; then
    rm -rf $encoded_videos
    show_msg "Delete old result in:$encoded_videos"
fi
mkdir $encoded_videos

if test -f $yuv_result; then
    show_msg "The yuv_result has already exsisted, delete it"
    rm $yuv_result
fi

decode_cost=0
encode_cost=0

Decode () {
    show_msg "Decoding $1 into $yuv_result"

    begin=$(gdate +%s.%N)

    ffmpeg -i $1 -c:v rawvideo -pix_fmt yuv420p $yuv_result > /dev/null 2>&1

    end=$(gdate +%s.%N)
    show_msg "Finish decoding begin:$begin, end:$end"

    cost=$(echo "scale=2;$end*1000-$begin*1000"|bc)
    decode_cost=$cost
    show_result "the decode time cost is:$cost(ms)"
    printf "$cost," >> $2
}

Encode () {
    show_msg "Encoding $1 into $4"

    begin=$(gdate +%s.%N)

    ffmpeg -f rawvideo -pix_fmt yuv420p -s:v $2x$3 -r 25 -i $yuv_result -c:v libx264 $4 > /dev/null 2>&1

    end=$(gdate +%s.%N)
    show_msg "Finish decoding begin:$begin, end:$end"

    cost=$(echo "scale=2;$end*1000-$begin*1000"|bc)
    encode_cost=$cost
    show_result "the encode time cost is:$cost(ms)"
    printf "$cost," >> $5

    if test -f $yuv_result; then
        rm $yuv_result
    fi
}

for FILE in *; do
    if [[ $FILE == *.mp4  ]]; then
        filename="${FILE%%.*}"
        split_files="split_files/$filename"
        frame_count=$(ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 $FILE)
        show_msg "The frame count of $FILE is:$frame_count"
        for (( i = 0; i < $repeat_times; i++ )); do
            printf "$FILE," >> $decode_result_file
            printf "$FILE," >> $encode_result_file

            width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nw=1:nk=1 $FILE)
            height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nw=1:nk=1 $FILE)

            # decode and encode original file
            Decode $FILE $decode_result_file
            original_decode_cost=$decode_cost

            Encode $FILE $width $height "$encoded_videos/${i}_${FILE}" $encode_result_file
            original_encode_cost=$encode_cost

            if [ ! -d "$split_files" ]; then
                show_err "$split_files does not exsist, need to fix"
                exit -1
            fi
            # decode and encode sub video files
            cd $split_files

            # delete exsisted yuv file
            if test -f $yuv_result; then
                show_msg "The yuv_result has already exsisted, delete it"
                rm $yuv_result
            fi

            sum_subvideo_decode_cost=0
            sum_subvideo_encode_cost=0

            for SPLIT_FILE in *; do
                Decode $SPLIT_FILE "../../$decode_result_file"
                sum_subvideo_decode_cost=$(echo "scale=2;$sum_subvideo_decode_cost+$decode_cost"|bc)

                sub_width=$(echo "scale=0;$width/$width_split_num"|bc)
                sub_height=$(echo "scale=0;$height/$height_split_num"|bc)
                show_msg "Encode width:$sub_width height:$sub_height"
                Encode $SPLIT_FILE $sub_width $sub_height "../../$encoded_videos/${i}_${SPLIT_FILE}" "../../$encode_result_file"
                sum_subvideo_encode_cost=$(echo "scale=2;$sum_subvideo_encode_cost+$encode_cost"|bc)
            done
            cd ../..

            # measurement calculation
            show_result "The sum subvideo decode cost is:$sum_subvideo_decode_cost"
            printf "$sum_subvideo_decode_cost," >> $decode_result_file
            decode_cost_increasement=$(echo "scale=2;$sum_subvideo_decode_cost-$original_decode_cost"|bc)
            show_result "The decode cost increasement is:$decode_cost_increasement"
            printf "%s," "$decode_cost_increasement" >> $decode_result_file
            printf "$frame_count," >> $decode_result_file
            avg_frame_increasement=$(echo "scale=2;$decode_cost_increasement/$frame_count"|bc)
            printf "%s\n" "$avg_frame_increasement" >> $decode_result_file
            show_result "The average decode cost increasement is:$avg_frame_increasement"

            show_result "The sum subvideo encode cost is:$sum_subvideo_encode_cost"
            printf "$sum_subvideo_encode_cost," >> $encode_result_file
            encode_cost_increasement=$(echo "scale=2;$sum_subvideo_encode_cost-$original_encode_cost"|bc)
            show_result "The encode cost increasement is:$encode_cost_increasement"
            printf "%s," "$encode_cost_increasement" >> $encode_result_file
            printf "$frame_count," >> $encode_result_file
            avg_frame_increasement=$(echo "scale=2;$encode_cost_increasement/$frame_count"|bc)
            printf "%s\n" "$avg_frame_increasement" >> $encode_result_file
            show_result "The average encode cost increasement is:$avg_frame_increasement"
        done
    fi
done

#------------------------------------------------------

show_msg "Run measurement complete!"
