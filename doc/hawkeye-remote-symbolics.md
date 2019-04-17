# MTHawkeye remote symbolics

During test, most of App wouldn't contain symbol table, so MTHawkeye extracts the method address symbolics into a service, which can be implemented by the server, while the client only do uploading the necessary information.

The class `MTHStackFrameSymbolicsRemote` is responsible for configuring the service address, and assembling the original data into the request body required by the protocol, then post to the server, and parsing the final response result into the specified format.

## Symbolics stack frame

```sh
POST /your_own_server
```

### Parameters

| Name | Type | Description |
| --- | --- | --- |
| dyld_images_info | object | required, dyld_images_info, see `[MTHawkeyeDyldImagesStorage cachedDyldImagesInfo]` for detail |
| arch | string | optional |
| model | string | optional |
| os_version | string | optional |
| name | string | optional |
| dyld_images | object | required |
| addr | string | required |
| addr_slide | string | optional |
| uuid | string | required |
| name | string | optional |
| stack_frames | array of string | required, the stack frame need to be symbolics |

### Request Example

```JSON
{
    "dyld_images_info": {
        "arch": "arm64 v8",
        "model": "16B92",
        "os_version": "12.1",
        "name": "Meipai",
        "dyld_images": [
            {
                "addr":"0x1002034",
                "addr_slide":"0x002024",
                "uuid":"23024352u5982752",
                "name":"MTHawkeye"
            }
        ]
    },
    "stack_frames": [
        "0x18ee92708",
        "0x18ee92722",
        "0x18ee92333",
        "0x18ee92221",
        "0x18ee92998"
    ]
}
```

### Response

```JSON
{
    "stack_frames":[
        {
            "addr": "0x1002034",
            "fname": "MTHawkeye",
            "fbase": "0x1001000",
            "sname": "[AClass method1]",
            "sbase": "0x1002034"
        }
    ],
    "error":{
        "msg": ""
    }
}
```

## Setup server for client

```objc
[MTHStackFrameSymbolicsRemote configureSymbolicsServerURL:@"your-own-server"];
```