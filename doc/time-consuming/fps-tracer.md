# Hawkeye - FPS Trace

`FPS Trace` records the FPS value and provides a floating window widget to display the FPS.

If `GPUImage` is used as the camera output, the framebuffer present FPS is also provided by `FPS Trace`.

The default recording interval of FPS is 0.5 second. If a record is equal to half a second ago, then only turn on (default off) `statusFlushKeepRedundantRecords` in `MTHawkeyeUserDefaults`, `FPS Trace` will record the new one, otherwise will skip. While readout, you may have to fill the empty equal records in timeline by yourself.

## Storage

When `FPS Trace` is add to `MTHawkeyeClient`, `FPS` value will be store in [Records file](./../hawkeye-storage.md#0x02-built-in-plugin-data-storage-instructions) once it needed.

it use `fps` as the `collection` name (while `gl-fps` for GPUImage framebuffer present), `key` is the time record, `value` is the FPS value.

```txt
colletion,key,value
...
fps,1554251562.052403,59
fps,1554251562.502282,60
gl-fps,1554251562.502299,28
```