# Compile and Run:

```bash
docker build . -t custom-ubuntu:latest

docker run --rm --privileged -v "$(pwd)/output:/output" custom-ubuntu:latest
```

## Performence Stats

Initial `docker build` takes 1 minute for fetching Ubuntu-ISO(4Gb)

`docker run` takes 1:10 minutes with 24 thread CPU

### Estimated Runtime:
`(27 / <CPU-threads>)` Minutes