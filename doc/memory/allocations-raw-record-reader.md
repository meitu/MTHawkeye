# Hawkeye Allocation Raw Record Reader

You can use `MTHAllocationsReader` to generate allocations report from the raw record files. Build a new one with `MTHAllocationReader` project or get it under `{Hawkeye_PROJ_ROOT}/MTHAllocationsReader/bin/`

Before:

```md
├── allocations
│   ├── dyld-images
│   ├── malloc_records_raw
│   └── vm_records_raw
│   ├── stacks_records_raw
```

After:

```md
├── allocations
│   ├── dyld-images
│   ├── malloc_records_raw
│   ├── vm_records_raw
│   ├── stacks_records_raw
│   ├── malloc_report           // generate by `MTHAllocationReader`
│   └── vm_report               // generate by `MTHAllocationReader`
```

command require arguments:

```shell
-d/--directory, allocations record files directory
-m/--malloc_threshold, malloc report threshold in byte
-v/--vmalloc_threshold, vmallocate report threshold in byte
```

example:

```shell
# generate allocation report
./MTHAllocationsReader -d ~/your-path/allocations -v 1024000 -m 10240
```
