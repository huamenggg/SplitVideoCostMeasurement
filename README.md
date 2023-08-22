# Split Video Cost Measurement

#### measure_cost_increasement.sh
If we want to get the final measurement result of splitting the videos to encode and decode, we only need to run the measure_cost_increasement.sh script. The input parameters is  [videos_directory], [width_split_size], [height_split_size], [repeat_times].
For example, we want to get the cost increase of splitting the videos in 'resources' into 2x2 sub-videos, and repeat each file three times, the command line is:
```
./measure_cost_increasement.sh resources 2 2 3
```
The result will be in 'resources/decode_result.csv' and 'resources/encode_result.csv'

#### split_video.sh
This script is to split the original video into sub-videos. The input parameters is [videos_directory], [width_split_size], [height_split_size]
For example, we want to split the videos in 'resources' into 2x2 sub-videos, the command line is:
```
./split_video.sh resources 2 2
```
