# custom config
`docker build --no-cache -t v2rayng-custom .` - build image

RUN BUILD APK:

```
docker run --rm -v $(pwd)/output:/output v2rayng-custom assembleRelease -PmyArgument=https://example.com/s/123123123123 --stacktrace --info --console=plain
```
