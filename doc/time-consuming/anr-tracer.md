# Hawkeye - ANR Trace

`ANR Trace` is used to capture the main thread stalling event, and will sampling the main thread stack frame when the jam occurs.

## 0x00 Usage

After add `ANR Trace` to `MTHawkeyeClient`, by default it'll start after `MTHawkeyeClient` run, you can change it by following steps:

1. Tap MTHawkeye floating window, enter the main panel.
2. Tap navigation title view, show the MTHawkeye panel switching view.
3. Tap `Setting` in the upper right corner of the switching view, enter the Setting view home.
4. Find `TimeConsuming` and go to `ANR Trace`, turn off `Trace ANR`, configure `ANR Threshold`

## 0x01 Record stalling event

When a method executed on main thread takes longer than the specified threshold (the default is 400ms), `ANR Trace` will capture a stalling event, and sampling the stack frame of main thread. You can see the recorded stalling events and details within the App while development.

![ANR Record list](./anr-record-list.png) ![ANR Record detail](./anr-record-detail.png)

If you need a accurate duration time while stalling and the detail calls, consider using [UI Time Profiler](./ui-time-profiler.md)

## 0x02 Hard stall event

When the app run into hard stall, it may killed without any logs, you can use `MTHANRTracingBuffer` to cache and restore the last running context.


## 0x03 Storage

ANR records is store under [Records file](./../hawkeye-storage.md#0x02-built-in-plugin-data-storage-instructions). Use a `collection` name `anr`, `key` as the time stalling event generated (The version after 0.12.1 optimizes it, it will split the >16kb or more of the Carton data and store it again. The `key` will become the `timestamp_serial number`, which needs to be merged when used externally. Please refer to the merge method in `readANRRecords`), `value` is a JSON string with the following fields:

- `duration`: stalling duration, in millisecond
- `inBackground`: whether it is running in the background
- `stacks`: all stack frame during stalling event 
    - `capturedCount`: the number of times recorded, the same record will be deduplicated
    - `stackframes`: sampling stack frame when the stalling event captured (symbolic needed), hexadecimal address string separated by `,`
    - `threadCount`: current thread count
    - `time`: the time stalling event generated
    - `titleframe`: stall event stack title string
- `startFrom`: stalling start time, in seconds

examples:

```json
{
    duration = "610.3181838989258";
    inBackground = 0;
    stacks = {
            capturedCount = 1;
            stackframes = "0x10d8fe55e,0x10d896497,0x108455f9a,0x108455c01,0x108455620,0x116a5d3d4,0x116a5d7b1,0x116888611,0x11687945f,0x1168a8865,0x10d8c4856,0x10d8bf2ed,0x10d8bf969,0x10d8bf055,0x10fa8fbaf,0x11687f88c,0x108460821,0x10e0084ac";
            threadCount = 6;
            time = "1565256930.870066";
            titleframe = 0x108455f9a;
        },
        {
            capturedCount = 1;
            stackframes = "0x10d90461b,0x10d8fe6f5";
            threadCount = 6;
            time = "1565256930.975193";
            titleframe = 0x10d90461b;
        }
    startFrom = "1565256930.414564";
}
```

## 0x03 Symbolics

`ANR Trace` records raw stack frame need to symbolized for reading.

If the running App do have DWARF within, you can directly use `ANR Trace` panel to view the symbolized result generated internal.

In other cases, if you have your own [remote symbolization service](./../hawkeye-remote-symbolics.md) and did set, switch on the `Remote Symbolics`, and then you can view the symbolized stack frame directly in the App.

If you wanna get the raw data from the sandbox, manual symbolize yourself as follows:

1. Get the `dyld-images` file in the MTHawkeye storage directory.
2. Get the raw stack frame data from the records.
3. Get the `dSYM` files
4. for each `frame`
    - find the match `dyld-image` by `frame` value, then match a `dSYM` file.
    - Use `atos` command to symbolize the `frame`.
