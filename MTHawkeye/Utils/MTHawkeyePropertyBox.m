//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 10/10/2017
// Created by: EuanC
//


#import "MTHawkeyePropertyBox.h"

mthawkeye_property_box mthawkeye_extract_property(objc_property_t property) {
    mthawkeye_property_box box;
    memset(&box, 0, sizeof(box));

    box.property_name = property_getName(property);
    box.attributtes_short = property_getAttributes(property);

    if (box.property_name == NULL || box.attributtes_short == NULL || box.property_name[0] == '\0' || box.attributtes_short[0] == '\0')
        return box;

    const char *pos = box.attributtes_short;
    do {
        size_t field_len = strcspn(pos, ",");
        if (field_len == 1) {
            if (pos[0] == 'R')
                box.is_readonly = true;
            else if (pos[0] == 'C')
                box.is_copy = true;
            else if (pos[0] == '&')
                box.is_strong = true;
            else if (pos[0] == 'W')
                box.is_weak = true;
            else if (pos[0] == 'N')
                box.is_nonatomic = true;
            else if (pos[0] == 'D')
                box.is_dynamic = true;
        } else if (field_len > 1) {
            if (pos[0] == 'V' && field_len < 512) {
                strncpy(box.ivar_name, pos + 1, field_len - 1);
                box.ivar_name[field_len] = '\0';
            } else if (pos[0] == 'T' && field_len < 128) {
                strncpy(box.type_name, pos + 1, field_len - 1);
                box.type_name[field_len] = '\0';
            }
        }
        pos += field_len;
    } while (*pos++);

    return box;
}
