#!/bin/bash

show_msg() {
    echo -e "\033[36m$1\033[0m"
}

show_err() {
    echo -e "\033[31m$1\033[0m"
}

# Check input
if [ "$#" -ne 3 ]; then
    show_err "Need to input the test video resource directory path and the split size!"
    show_err "The input format should be ./split_video.sh directory 2 2"
    exit 1
fi

video_directory=$1

if [ ! -d "$video_directory" ]; then
  show_err "The test directory '$video_directory' does not exist!"
  exit 1
fi

width_split_num=$2
height_split_num=$3

if [ $width_split_num -le 0 ] || [ $height_split_num -le 0 ]; then
  show_err "The input split size should be greater than 0!"
  exit 1
fi

# finish check input

show_msg "============= Spliting Program Start ==================="

cd $video_directory

# splited videos direcotry
split_files="split_files"
if [ ! -d "$split_files" ]; then
    show_msg "Creating splited files in:$split_files"
    mkdir $split_files
fi

for FILE in *; do
    if [[ $FILE == *.mp4  ]]; then
        show_msg "Spliting $FILE ..."
        cropped_width="iw/$width_split_num"
        cropped_height="ih/$height_split_num"
        filename="${FILE%%.*}"
        echo $filename
        output_dir="$split_files/$filename"
        if [ ! -d "$output_dir" ]; then
            show_msg "Creating output directory in:$output_dir"
            mkdir $output_dir
        fi
        for (( i = 0; i < $width_split_num; i++ )); do
            for (( j = 0; j < $height_split_num; j++ )); do
                output_file="$output_dir/${filename}_width${i}_height${j}.mp4"
                if [ ! -f $output_file ]; then
                    show_msg "Generating $output_file ..."
                    ffmpeg -i $FILE -filter:v "crop=$cropped_width:$cropped_height:$i*$cropped_width:$j*$cropped_height" $output_file > /dev/null 2>&1
                else
                    show_err "Already have same name file:$output_file"
                fi
            done
        done
    fi
done

show_msg "Run split script complete!"
show_msg "============= Spliting Program End ==================="
