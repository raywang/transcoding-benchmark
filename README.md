# EC2 transcoding performance and video quality benchmark test with FFmpeg

## FFmpeg (latest version) compling and installing on EC2

### x86/Graviton instances setup (C5,C6i,C6a,C6g,C7g)

```
bash setup-cpu.sh
```

## FFmpeg transcoding performance benchmark test on EC2

The performance metrics Total FPS (frames per second) will show after the benchmark script finish running, and the results will be logged in logs/{instance type}/results.log as well.

### Prerequesite

Create the S3 bucket and path for storing input/output files, uploaded the 1080p/4K input files into the bucket, make sure INPUT_BUCKET, OUTPUT_BUCKET and INPUT_FILE of each script in this section are set properly

### Benchmark HD/4K transcoding performance on CPU instances

* 1080p h.264 transcoding

Usage:  bash 264to264_benchmark_cpu.sh {batch size} {ec2 instance type} {transcoding bitrate}

        batch size: concurrent number of ffmpeg transcoding process (make cpu utilization close to 100%)
        ec2 instance type: instance type of ec2 for transcoding
        transcoding bitrate: bitrate for transcoding, e.g. 800k, 2M
Sample:

```
bash 264to264_benchmark_cpu.sh 5 C6g.4x 2.5M
```

* 4K h.265 transcoding

Usage:  bash 265to265_benchmark_cpu.sh {batch size} {ec2 instance type} {transcoding bitrate}

        batch size: concurrent number of ffmpeg transcoding process (make cpu utilization close to 100%)
        ec2 instance type: instance type of ec2 for transcoding
        transcoding bitrate: bitrate for transcoding, e.g. 800k, 2M
Sample:

```
bash 265to265_benchmark_cpu.sh 3 C7g.4x 8M
```
